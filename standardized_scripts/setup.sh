#!/bin/bash
set -ex
#Initialize Helm Client
helm init --client-only
#Update to allow kubectl installation
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update -y && apt-get install -y kubectl
#Build rabbitmq chart
build_dir=$(mktemp -d)
cd $build_dir
git clone https://github.com/openstack/openstack-helm-infra.git
cd openstack-helm-infra/
mkdir -p ./rabbitmq/charts
cp -rav ./helm-toolkit ./rabbitmq/charts/
#Package rabbitmq chart
helm package ./rabbitmq


# you'll get a chart tarball - that needs to go somewhere
#Ger certificate
kubectl get -n harbor secrets harbor-harbor-harbor-nginx -o 'go-template={{ index .data "ca.crt" | base64decode }}' > ./temp-ca.crt
#how to push to harbor with chartmuseum
helm repo add --ca-file ./temp-ca.crt --username=admin --password=Harbor12345 tcicd https://stacey-0.localdomain:30003/chartrepo/tcicd

helm plugin install https://github.com/chartmuseum/helm-push
helm push --ca-file ./temp-ca.crt --username=admin --password=Harbor12345 ./rabbitmq-0.1.0.tgz tcicd