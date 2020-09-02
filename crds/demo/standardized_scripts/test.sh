# run helm test
set -ex
helm init --client-only
helm test demo-rabbitmq --logs --cleanup --timeout 600