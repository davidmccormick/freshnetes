#!/bin/bash
set -e

echo "Looking for fresh versions,"

# Download the freshest kubernetes.

KUBERNETES_VERSION=$(curl -s -k -L https://storage.googleapis.com/kubernetes-release/release/stable.txt)
KUBEADM_VERSION="v1.5.0-alpha.0-1534-gcf7301f"
ETCD_VERSION=$(curl -k -v https://github.com/coreos/etcd/releases/latest 2>&1 | awk '($2 == "Location:"){print $3}' | tr -dc '[:alnum:]/.')
ETCD_VERSION=${ETCD_VERSION##*/}
FLANNEL_VERSION=$(curl -k -v https://github.com/coreos/flannel/releases/latest 2>&1 | awk '($2 == "Location:"){print $3}' | tr -dc '[:alnum:]/.')
FLANNEL_VERSION=${FLANNEL_VERSION##*/}

function use_or_update {
  local NAME=$1
  local LATEST=$2
  local DOWN_URL=$3
  local FILE=$4

  #Default to download unless we have the latest
  local DOWNLOADNEW="true"

  if [[ -f "./.${NAME}.version" && -f "${FILE}" ]]; then
    local CURRENT=$(cat ./.${NAME}.version)
    if [[ "$CURRENT" == "${LATEST}" ]]; then
      echo "${NAME} ${CURRENT} is fresh"
      DOWNLOADNEW="false"
    else
      echo "Cached ${NAME} ${CURRENT} is not fresh."
    fi
  fi

  if [[ "$DOWNLOADNEW" == "true" ]]; then
    echo "Downloading and caching ${NAME} ${LATEST}"
    echo "curl -f -k -L ${DOWN_URL} >${FILE}"
    curl -k -L ${DOWN_URL} >${FILE}
    echo "${LATEST}" >./.${NAME}.version
  fi

  return 0
}

echo "Checking for freshest Kubernetes platforms software releases..." 
use_or_update "kubernetes" "${KUBERNETES_VERSION}" "https://github.com/kubernetes/kubernetes/releases/download/$KUBERNETES_VERSION/kubernetes.tar.gz" "./kubernetes.tar.gz"
if [[ ! -d "kubernetes" || $(cat kubernetes/version) != "$KUBERNETES_VERSION" ]]; then
  echo "Extracting Kubernetes soure repository..."
  [[ -d "kubernetes" ]] && rm -rf kubernetes
  tar xfp kubernetes.tar.gz
  echo "Extracting Hyperkube and server components..."
  cd kubernetes/server
  tar xfp kubernetes-server-linux-amd64.tar.gz 
fi
echo "Downloading kubeadm command..."
use_or_update "kubeadm" "${KUBEADM_VERSION}" "https://storage.googleapis.com/kubeadm/${KUBEADM_VERSION}/bin/linux/amd64/kubeadm" "./kubeadm"
chmod +x kubeadm


use_or_update "etcd" "${ETCD_VERSION}" "https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz" "./etcd-linux-amd64.tar.gz"
use_or_update "flannel" "${FLANNEL_VERSION}" "https://github.com/coreos/flannel/releases/download/${FLANNEL_VERSION}/flannel-${FLANNEL_VERSION}-linux-amd64.tar.gz" "./flannel-linux-amd64.tar.gz"

