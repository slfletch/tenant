#!/bin/bash
# shellcheck source=/dev/null
shopt -s globstar

. "${TENANT_HOME}/utils.sh"

finish_run() {
    if ! ls "${TENANT_OUTPUT}"/**/tenant-output*.yaml; then
        infralog "==== RUN step did not produce required ${TENANT_OUTPUT}/**/tenant-output.yaml"
        exit 1
    fi
}

trap finish_run EXIT

# Only run if the stop flag is not set
if [ -f "${TENANT_HOME}/stop.flag" ]; then
    infralog "==== RUN step is not starting because stop has been requested"
else
    run_tenant_target "run" "${TENANT_RUN}"
fi
