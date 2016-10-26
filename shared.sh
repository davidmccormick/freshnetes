#!/bin/env bash

set -e

# This script sets up Etcd, Flannel and Kubernetes Master
# for a single master and 3 minions configuration.

echo "***************************************"
echo "*       RUNNING SHARED SETUP          *"
echo "***************************************"

echo "Add /usr/local/bin to PATH"
export PATH="$PATH:/usr/local/bin"

echo "Disabling ipv6"
for A in net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6 net.ipv6.conf.lo.disable_ipv6 
do
	grep $A /etc/sysctl.conf || (echo "$A = 1" | tee -a /etc/sysctl.conf && sysctl $A=1) 
done

# Disable Networkmanager
systemctl stop NetworkManager

echo "Setting up /etc/hosts"
# Set up hosts file for resolution of master and minions via Vagrant private network
cat <<-EOF >/etc/hosts
127.0.0.1       localhost localhost.localdomain localhost4 localhost4.localdomain4
::1             localhost localhost.localdomain localhost6 localhost6.localdomain6
10.250.250.2   master.example.com master
10.250.250.10  minion01.example.com minion01
10.250.250.11  minion02.example.com minion02
10.250.250.12  minion03.example.com minion03
EOF
cat /etc/hosts

echo "Installing docker"
#dnf -y install docker
#systemctl start docker
cat >/etc/yum.repos.d/docker.repo <<-EOF
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7
enabled=1
gpgcheck=0
gpgkey=https://yum.dockerproject.org/gpg
EOF
yum -y install docker-engine
systemctl start docker

echo "Adding /usr/local/bin and /usr/local/sbin to root's path after sudo"
sed -e 's@^Defaults.*secure_path.*$@Defaults    secure_path = /usr/local/bin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin@' -i /etc/sudoers

echo "Extracting kubernetes"
cp /home/vagrant/hyperkube /usr/local/bin
cp /home/vagrant/kubeadm /usr/local/bin
cd /usr/local/bin
./hyperkube --make-symlinks
echo "Configure kubectl"
kubectl config set-cluster default-cluster --server=http://master:8080
kubectl config set-context default --cluster=default-cluster --user=cluster-admin
kubectl config use-context default
# Show us the kubeconfig and write to convenient file
echo "Kubectl is:"
kubectl config view | tee /root/kubeconfig

echo "Extracting Flannel"
cd /home/vagrant
tar xfz flannel-linux-amd64.tar.gz
cp flanneld /usr/local/bin
cp mk-docker-opts.sh /usr/local/bin

echo "***************************************"
echo "*       FINISHED SHARED SETUP         *"
echo "***************************************"


