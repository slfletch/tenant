#!/bin/bash
# Orchestrate the setup -> run -> teardown sequence
# Teardown always executes due to trap.
# RC from this script is either the SETUP_RC, the RUN_RC (if it ran),
# or finally the TEARDOWN_RC if there was a failure during teardown
# When there is a failure in any stage, the framework log is written to
# standard out.
# shellcheck source=/dev/null

[ "${TENANT_OUTPUT}" ] && OUTPUT_DIR="${TENANT_OUTPUT}" || OUTPUT_DIR="${TENANT_HOME}/output/"
[ "${TENANT_FRAMEWORK_LOG}" ] && LOG_FILE="${TENANT_FRAMEWORK_LOG}" || LOG_FILE="${OUTPUT_DIR}/TENANT_framework.log"
[ "${TENANT_STOPPER_PORT}" ] && STOPPER_PORT="${TENANT_STOPPER_PORT}" || STOPPER_PORT="60106"
[ "${TENANT_OUTPUT_DIAGNOSTICS}" ] && DIAGNOSTICS_DIR="${TENANT_OUTPUT_DIAGNOSTICS}" || DIAGNOSTICS_DIR="${OUTPUT_DIR}/diagnostic/"

stopper() {
    # Setup a listener on the stopper port to trigger the stop listener
    echo -e 'HTTP/1.1 200 OK' | nc -l ${STOPPER_PORT} | ${TENANT_HOME}/stop_listener.sh &
    infralog "==== Stop listener on port ${STOPPER_PORT}"
}

end_stopper() {
    # clear the stop flag if it is present
    if [ -f "${TENANT_HOME}/stop.flag" ]; then
        rm "${TENANT_HOME}/stop.flag"
    fi

    # Stop the stop_listener.sh pid (first)
    STOP_SL_PID="$(pgrep -f "stop_listener.sh")"
    if [ "z${STOP_SL_PID}" != "z" ]; then
        infralog "==== Shutting down the stop listener script using pid ${STOP_SL_PID}"
        kill "${STOP_SL_PID}" || true
    fi

    # Stop the Netcat pid
    STOP_NC_PID="$(pgrep -f "nc -l ${STOPPER_PORT}")"
    if [ "z${STOP_NC_PID}" != "z" ]; then
        infralog "==== Shutting down the nc on port ${STOPPER_PORT} using pid ${STOP_NC_PID}"
        kill "${STOP_NC_PID}" || true
    fi
}

# When no tenant-output.yaml is produced, write a default "empty" one.
default_tenant_output() {
    if [ ! -n "$(find ${TENANT_OUTPUT} -name 'TENANT-output*.yaml' -print -quit)" ]; then
        warnlog "Suite did not produce any TENANT-output*.yaml. An empty TENANT-output.yaml has been supplied by the suite framework"
        echo "test_case_info: []" > "${TENANT_OUTPUT}"/tenant-output.yaml
    fi
}

# When any stage has failed, dump a directory listing of the TENANT home directory to the output directory file-list.debug.txt
dump_tenant_dir() {
    mkdir -p "${DIAGNOSTICS_DIR}"
    FILE_LIST_DEBUG="${DIAGNOSTICS_DIR}/file-list-debug.txt"
    echo "A listing of all directories under ${TENANT_HOME}" > "${FILE_LIST_DEBUG}"
    ls -lR "${TENANT_HOME}" >> "${FILE_LIST_DEBUG}"
}

SETUP_RC=0
RUN_RC=0
TEARDOWN_RC=0
FINALLY_RC=0

setup_stage() {
    "${TENANT_HOME}/setup.sh"
    SETUP_RC="$?"
}

run_stage() {
    "${TENANT_HOME}/run.sh"
    RUN_RC="$?"
}

teardown_stage() {
    "${TENANT_HOME}/teardown.sh"
    TEARDOWN_RC="$?"
}

finally_stage() {
    "${TENANT_HOME}/finally.sh"
    FINALLY_RC="$?"
}

finalize() {
    end_stopper
    teardown_stage
    finally_stage
    default_TENANT_output
    # Ouptut a directory listing of the home directory into a file if any of the stages don't end cleanly
    if [ "${SETUP_RC}" -ne 0 ] || [ "${RUN_RC}" -ne 0 ] || [ "${TEARDOWN_RC}" -ne 0 ] || [ "${FINALLY_RC}" -ne 0 ]; then
        dump_tenant_dir
    fi
    # Allow the prior rc propogate, unless teardown failed too.
    # Logs will show all stage RCs, but this ensures that if teardown fails
    # the RC is impacted.
    if [ "${TEARDOWN_RC}" -ne 0 ]; then
        exit "${TEARDOWN_RC}"
    fi
}

set +e
trap finalize EXIT

stopper
setup_stage

# Only Run if setup was successful.
if [ "${SETUP_RC}" == 0 ]; then
    run_stage
    exit "${RUN_RC}"
else
    infralog "Skipping RUN because SETUP was unsuccessful"
    # Exit with SETUP's RC
    exit "${SETUP_RC}"
fi