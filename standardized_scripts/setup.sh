echo "Running my setup"

#git clone https://github.com/openstack/openstack-helm-infra.git
#cd openstack-helm-infra/
#mkdir -p ./rabbitmq/charts
#cp -rav ./helm-toolkit ./rabbitmq/charts/
#helm package ./rabbitmq

cat <<EOF | kubectl apply -f -
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: myrabbit
spec:
  releaseName: myrabbitmq
  timeout: 300
  resetValues: false
  wait: false
  forceUpgrade: false
  chart:
    repository: https://kubernetes-charts.storage.googleapis.com
    name: rabbitmq
    version: 6.18.2
  values:
    persistence:
      storageClass: nfs-provisioner
    replicas: 1
EOF

 #   helm install my-release \
 # --set persistence.storageClass=nfs-provisioner \
 #   stable/rabbitmq