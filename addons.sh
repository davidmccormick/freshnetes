echo "Enabling kubernetes addons"
mkdir -p /etc/kubernetes/addons
kubectl create namespace kube-system
kubectl config set-context kube-system --namespace=kube-system --cluster=default-cluster
echo "Adding the kube-addon-manager"
#curl -s https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/saltbase/salt/kube-addons/kube-addon-manager.yaml >/etc/kubernetes/addon-manager.yaml
cat >/etc/kubernetes/addon-manager.yaml <<EOT
apiVersion: v1
kind: Pod
metadata:
  name: kube-addon-manager
  namespace: kube-system
  labels:
    component: kube-addon-manager
    version: v4
spec:
  hostNetwork: true
  containers:
  - name: kube-addon-manager
    # When updating version also bump it in cluster/images/hyperkube/static-pods/addon-manager.json
    image: gcr.io/google-containers/kube-addon-manager:v5.1
    resources:
      requests:
        cpu: 5m
        memory: 50Mi
    volumeMounts:
    - mountPath: /etc/kubernetes/
      name: addons
      readOnly: true
    - mountPath: /root/.kube
      name: kube-config
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/
    name: addons
  - hostPath:
      path: /root/.kube/
    name: kube-config
EOT

kubectl create -f /etc/kubernetes/addon-manager.yaml --namespace=kube-system

