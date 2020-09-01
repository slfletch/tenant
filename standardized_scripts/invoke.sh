#!/bin/bash
set -ex
${TENANT_HOME}/setup.sh
${TENANT_HOME}/run.sh
${TENANT_HOME}/test.sh
