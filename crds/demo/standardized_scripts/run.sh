#!/bin/bash
helm init --client-only

#This can be done using Flux - flexibility of the pipeline, encapsulation in a script can be executed.
kubectl get -n harbor secrets harbor-harbor-harbor-nginx -o 'go-template={{ index .data "ca.crt" | base64decode }}' > ./temp-ca.crt
tee /tmp/values.yaml <<EOF
labels:
  server:
    node_selector_key: harbor
    node_selector_value: enabled
  prometheus_rabbitmq_exporter:
    node_selector_key: harbor
    node_selector_value: enabled
  test:
    node_selector_key: harbor
    node_selector_value: enabled
  jobs:
    node_selector_key: harbor
    node_selector_value: enabled
volume:
  class_name: nfs-provisioner
EOF
helm upgrade --wait --install --force demo-rabbitmq --ca-file ./temp-ca.crt --version 0.1.0 tcicd/rabbitmq --values /tmp/values.yaml