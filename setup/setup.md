#Assuming Kubernetes instance exists with kubectl/kubelet/kubeadm

#Install packages 

     sudo apt-get -y install nfs-common curl make docker.io git

#Install Helm 2 

     curl -LO https://git.io/get_helm.sh
     chmod 700 get_helm.sh
     ./get_helm.sh

#Create service account to allow access to objects

     kubectl create -n kube-system serviceaccount helm-tiller
     cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: helm-tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: helm-tiller
    namespace: kube-system
EOF

# Set up local helm server
sudo -E tee /etc/systemd/system/helm-serve.service << EOF
[Unit]
Description=Helm Server
After=network.target
[Service]
User=$(id -un 2>&1)
Restart=always
ExecStart=/usr/local/bin/helm serve
[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0640 /etc/systemd/system/helm-serve.service

sudo systemctl daemon-reload
sudo systemctl restart helm-serve
sudo systemctl enable helm-serve

#Initialize helm server
helm init --service-account helm-tiller --output yaml   | sed 's@apiVersion: extensions/v1beta1@apiVersion: apps/v1@'   | sed 's@  replicas: 1@  replicas: 1\n  selector: {"matchLabels": {"app": "helm", "name": "tiller"}}@'   | kubectl apply -f -

# Remove stable repo, if present, to improve build time
helm repo remove stable || true

#Add label to node used for deployment of Harbor
kubectl label nodes stacey-0 harbor=enabled

#Install nfs-provisioner for storage
git clone https://github.com/slfletch/tenant
cd charts
make
helm upgrade --install nfs-provisioner ./nfs-provisioner --namespace=nfs

#Add fluxcd repo to helm (using flux helm operator to deploy Harbor)
kubectl create ns flux

helm repo add fluxcd https://charts.fluxcd.io
#Add helm operator crd
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/1.2.0/deploy/crds.yaml

#Make sure helm operator can do helm 2 and helm 3
helm upgrade -i helm-operator fluxcd/helm-operator     --namespace flux
## Deploy nfs using openstack-helm-infra w/some tweaks
## Deploy harbor, nginx, notary, portal, redis, registry, trivy, clair, chartmuseum, database
cat <<EOF | kubectl apply -f -
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: harbor
  namespace: harbor
spec:
  chart:
    repository: https://helm.goharbor.io/
    name: harbor
    version: 1.4.0
  values:
    expose:
      type: nodePort
      tls:
        commonName: stacey-0.localdomain
      ingress:
        hosts:
          core: stacey-0.localdomain
    externalURL: https://stacey-0.localdomain:30003
    trivy:
      securityContext:
        runAsNonRoot: false
    persistence:
      persistentVolumeClaim:
        registry:
          storageClass: nfs-provisioner
        chartmuseum:
          storageClass: nfs-provisioner
        jobservice:
          storageClass: nfs-provisioner
        database:
          storageClass: nfs-provisioner
        redis:
          storageClass: nfs-provisioner
        trivy:
          storageClass: nfs-provisioner
EOF
cat <<EOF | kubectl apply -f -
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: rabbitmqhe
  namespace: harbor
spec:
  chart:
    repository: https://review.opendev.org/openstack/openstack-helm-infra
    name: nfs-provisioner
    version: 0.1.0
EOF

#Install tekton
git clone https://github.com/slfletch/pipeline
cd pipeline
git checkout release-v0.15.x

kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=ubuntu

kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

#Create a persistent volume for tekton
cd /home/ubuntu/tcicd/steps
kubectl apply -f tekton-pv.yaml

sudo apt update;sudo apt install -y gnupg
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3EFE0E0A2F2F60AA
echo "deb http://ppa.launchpad.net/tektoncd/cli/ubuntu eoan main"|sudo tee /etc/apt/sources.list.d/tektoncd-ubuntu-cli.list
sudo apt update && sudo apt install -y tektoncd-cli

#Create role, rolebinding, serviceaccount from www.github.com/slfletch/tenant/crds/demo
kubectl create ns demo
kubectl apply -f demo-svc.yaml
kubectl apply -f demo-role.yaml
kubectl apply -f demo-rolebinding.yaml

#Run tekton TaskRun - Helm package, lint, publish, install, and helm test
kubectl apply -f demo-task-run_scdi.yaml

#Install Tekton Triggers (optional)
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
#Install tekton dashboard
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml

#Setup ingress
DASHBOARD_URL=stacey-0.localdomain
kubectl apply -n tekton-pipelines -f - <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: tekton-dashboard
  namespace: tekton-pipelines
spec:
  rules:
  - host: '*'
    http:
      paths:
      - backend:
          serviceName: tekton-dashboard
          servicePort: 9097
EOF

#Install nginx ingress - update controller.hostNetwork: true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx/
helm install --name ingress-nginx ingress-nginx/ingress-nginx --set controller.hostNetwork=true
