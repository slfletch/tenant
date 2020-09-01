#!/bin/bash

read -n 1 NOTHING
infralog "==== Signal to stop received via http"
# Sets a stop.flag file so that run.sh can check it before it kicks off the run.
# This serves as a flag that a stop was triggered, and is removed in the final steps of run
touch "${TENANT_HOME}/stop.flag"

"${TENANT_HOME}/stop.sh"
