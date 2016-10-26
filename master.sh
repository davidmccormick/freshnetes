#!/bin/env bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

echo "***************************************"
echo "*       RUNNING MASTER SETUP          *"
echo "***************************************"

echo "Extracting etcd"
cd /home/vagrant
tar xzf etcd-linux-amd64.tar.gz
cp etcd-*-linux-amd64/etcd /usr/local/bin
cp etcd-*-linux-amd64/etcdctl /usr/local/bin
cd /
mkdir -p /var/run/etcd-data
MY_PUBLIC_IP=$(ip route | grep 10.250.250 | awk '{print $9}')
ETC_HOSTNAME=$(hostname)
etcd --name=master --data-dir=/var/run/etcd-data --listen-client-urls=http://${MY_PUBLIC_IP}:2379 --advertise-client-urls=http://${ETC_HOSTNAME}:2379 --listen-peer-urls=http://${ETC_HOSTNAME}:2380 --initial-cluster=master=http://${ETC_HOSTNAME}:2380 --initial-advertise-peer-urls=http://${ETC_HOSTNAME}:2380 1>>/var/log/etcd.log 2>&1 &

echo "Waiting for etcd to come up ok"
set +e
HEALTH=""
etcdctl --endpoints=http://master:2379 cluster-health
[ $? -eq 0 ] && HEALTH="ok"
while [[ "$HEALTH" != "ok" ]]
do
  sleep 5
  etcdctl --endpoints=http://master:2379 cluster-health
  [ $? -eq 0 ] && HEALTH="ok"
done
set -e

sleep 1
echo "Configuring Flannel Network in etcd"
etcdctl --endpoints=http://${ETC_HOSTNAME}:2379 set /freshkube/network/config '{ "Network": "10.1.0.0/16" }'

echo "Starting Flannel"
MY_INTERFACE=`ip route | grep 10.250.250 | awk '{print $3}'`
echo "Checking etcd"
etcdctl --endpoints=http://${ETC_HOSTNAME}:2379 get /freshkube/network/config
echo "flanneld --etcd-endpoints=http://${ETC_HOSTNAME}:2379 --iface=$MY_INTERFACE --etcd-prefix=/freshkube/network" 
flanneld --etcd-endpoints=http://${ETC_HOSTNAME}:2379 --iface=$MY_INTERFACE --etcd-prefix=/freshkube/network 1>>/var/log/flannel.lo 2>&1 &
sleep 2
echo "Examining flannel area in etcd - ls /freshkube/network"
etcdctl --endpoints=http://${ETC_HOSTNAME}:2379 ls /freshkube/network


echo "Setting up kubernetes..."
mkdir -p /etc/kubernetes/master
echo "Creating serviceaccounts private key..."
openssl genpkey -algorithm RSA -out /etc/kubernetes/master/serviceacount_private_key.pem -pkeyopt rsa_keygen_bits:2048
echo "Downloading cert creation script..."
curl -k -L https://github.com/kubernetes/kubernetes/raw/master/cluster/saltbase/salt/generate-cert/make-ca-cert.sh >/usr/local/bin/make-ca-cert.sh
chmod +x /usr/local/bin/make-ca-cert.sh
MY_IP=$(ip addr | grep 10.250.250 | awk '{print $2}' | sed -e 's/\/.*$//')
export CERT_DIR="/etc/kubernetes/master"
export CERT_GROUP="root"
/usr/local/bin/make-ca-cert.sh "${MY_IP}" "IP:${MY_IP},IP:10.0.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local"

echo "Starting Kubernetes api server.."
apiserver --etcd-servers=http://${ETC_HOSTNAME}:2379 --bind-address=0.0.0.0 \
  --insecure-bind-address=0.0.0.0 \
  --insecure-port=8080 \
  --storage-backend=etcd3 \
  --allow-privileged=true \
  --service-cluster-ip-range=10.0.0.0/16 \
  --enable-garbage-collector=true \
  --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --v=4 \
  1>>/var/log/api-server.log 2>&1 &

echo "Starting Kubernetes controller-manager.."
controller-manager --master=http://master:8080 \
  --enable-garbage-collector=true \
  --service-account-private-key-file=/etc/kubernetes/master/serviceacount_private_key.pem \
  --v=4 1>>/var/log/controller-manager.log 2>&1 &

echo "Starting Kubernetes scheduler.."
scheduler --master=http://master:8080 \
  --v=4 1>>/var/log/controller-manager.log 2>&1 &

echo "Starting Kublet..."
kubelet --allow-privileged=true \
  --address=0.0.0.0 \
  --api-servers=http://master:8080 \
  --experimental-flannel-overlay=true \
  --enable-server \
  --cluster-dns=10.0.0.2 \
  --cluster-domain=example.com \
  --v=4 \
  1>>/var/log/kublet.log --enable-debugging-handlers=true 2>&1 &

echo "Starting Kube-Proxy..."
proxy --master=http://master:8080 \
  --bind-address=0.0.0.0 \
  --proxy-mode=iptables \
  --v=4 \
  1>>/var/log/proxy.log 2>&1 &

echo "Waiting for kubernetes api to come up ok"
set +e
HEALTH=""
kubectl get nodes
[ $? -eq 0 ] && HEALTH="ok"
while [[ "$HEALTH" != "ok" ]]
do
  sleep 5
  kubectl get nodes
  [ $? -eq 0 ] && HEALTH="ok"
done
set -e

echo "Setting up skydns for cluster DNS..."
cd /home/vagrant
tar xfp kubernetes-manifests.tar.gz
export DNS_REPLICAS="1"
export DNS_SERVER_IP="10.0.0.2"
export DNS_DOMAIN="example.com"
echo "Creating DNS replication controller in kube-system..."
echo "${DNS_REPLICAS} of DNS Server on ${DNS_SERVER_IP} for domain ${DNS_DOMAIN}..."
envsubst <kubernetes/addons/dns/skydns-rc.yaml | kubectl create -f -
envsubst <kubernetes/addons/dns/skydns-svc.yaml | kubectl create -f -
