#!/bin/env bash

set -e

# This script sets up Flannel, Docker and Kubernetes Node
# for a single master and 3 minions configuration.

while test $# -gt 0; do
  case "$1" in
    --schedule*) 
      export SCHEDULE=`echo $1 | sed -e 's/^[^=]*=//g'`
      ;;
    *)	break
      ;;
  esac
done

echo "***************************************"
echo "*       RUNNING MINION SETUP          *"
echo "***************************************"

echo "Setting up flannel"
sed -e 's/^FLANNEL_ETCD=.*$/FLANNEL_ETCD="http:\/\/master:2379"/' -i /etc/sysconfig/flanneld
sed -e 's/^FLANNEL_ETCD_KEY=.*$/FLANNEL_ETCD_KEY="\/atomic01\/network"/' -i /etc/sysconfig/flanneld
sed -e 's/^#FLANNEL_OPTIONS=.*$/FLANNEL_OPTIONS="--iface=eth1"/' -i /etc/sysconfig/flanneld
echo "/etc/sysconfig/flanneld:-"
cat /etc/sysconfig/flanneld

systemctl daemon-reload 2>&1
systemctl enable flanneld 2>&1
systemctl start flanneld 2>&1

echo "Setting up Docker"
sed -e 's/^OPTIONS=.*$/OPTIONS="--registry-mirror=http:\/\/master:5000 --log-driver=json-file --log-opt max-size=100m --log-opt max-file=5"/' -i /etc/sysconfig/docker
echo ". /run/flannel/docker" >/etc/sysconfig/docker-network
echo "/etc/sysconfig/docker:-"
cat /etc/sysconfig/docker

systemctl stop docker 2>&1
/usr/sbin/ip link del docker0
systemctl start docker 2>&1

echo "Setting up Kubernetes Minion"
sed -e 's/^KUBELET_ADDRESS=.*$/KUBELET_ADDRESS="--address=0.0.0.0"/' -i /etc/kubernetes/kubelet
sed -e 's/^KUBELET_HOSTNAME=.*$/KUBELET_HOSTNAME=""/' -i /etc/kubernetes/kubelet
sed -e 's/^KUBELET_API_SERVER=.*$/KUBELET_API_SERVER="--api_servers=http:\/\/master:8080"/' -i /etc/kubernetes/kubelet
sed -e 's/^KUBE_MASTER=.*$/KUBE_MASTER="--master=http:\/\/master:8080"/' -i /etc/kubernetes/config
if [[ "$SCHEDULE" == "false" ]]; then
  sed -e 's/^KUBELET_ARGS=.*$/KUBELET_ARGS="--register-schedulable=false"/' -i /etc/kubernetes/kubelet
fi	
echo "/etc/kubernetes/config: -"
cat /etc/kubernetes/config
echo "/etc/kubernetes/kubelet: -"
cat /etc/kubernetes/kubelet

echo "Starting kubelet and kubeproxy"
systemctl enable kubelet kube-proxy 2>&1
systemctl start kubelet kube-proxy 2>&1

echo "Configure kubectl"
kubectl config set-cluster default-cluster --server=http://master:8080
kubectl config set-context default --cluster=default-cluster --user=cluster-admin
kubectl config use-context default

echo "Enabling kubernetes addons"
mkdir -p /etc/kubernetes/addons

echo "Installing Dashboard Addon"
curl -s https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dashboard/dashboard-controller.yaml >/etc/kubernetes/addons/dashboard-controller.yaml
curl -s https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dashboard/dashboard-service.yaml >/etc/kubernetes/addons/dashboard-service.yaml 

echo "Installing Node Problem Detector Addon"
curl -s https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/node-problem-detector/node-problem-detector.yaml >/etc/kubernetes/addons/node-problem-detector.yaml


echo "Finished setting up Minion"

