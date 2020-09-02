#!/bin/bash
set -ex
helm init --client-only

#Build rabbitmq chart
build_dir=$(mktemp -d)
cd $build_dir
git clone https://github.com/openstack/openstack-helm-infra.git
cd openstack-helm-infra/
mkdir -p ./rabbitmq/charts
cp -rav ./helm-toolkit ./rabbitmq/charts/
#Package rabbitmq chart
helm package ./rabbitmq

#Check if the overall product renders
helm lint ./rabbitmq-0.1.0.tgz

#Get certificate from Harbor helm repository - Hardcoded for time purposes, in a non-POC world this ca would be bind mounted into the container
kubectl get -n harbor secrets harbor-harbor-harbor-nginx -o 'go-template={{ index .data "ca.crt" | base64decode }}' > ./temp-ca.crt

#Adding the chart repository to helm
helm repo add --ca-file ./temp-ca.crt --username=admin --password=Harbor12345 tcicd https://stacey-0.localdomain:30003/chartrepo/tcicd
#Push the chart to repository
helm plugin install https://github.com/chartmuseum/helm-push
helm push --ca-file ./temp-ca.crt --username=admin --password=Harbor12345 ./rabbitmq-0.1.0.tgz tcicd