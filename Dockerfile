# Copyright 2019 AT&T Intellectual Property.  All other rights reserved.
ARG FROM=lachlanevenson/k8s-kubectl:latest
FROM ${FROM} as build

ARG CTX_BASE="."
COPY "${CTX_BASE}"/"bin_scripts/*" "/usr/local/bin/"
RUN chmod +x "/usr/local/bin/errorlog" \
    && chmod +x "/usr/local/bin/infralog" \
    && chmod +x "/usr/local/bin/msglog" \
    && chmod +x "/usr/local/bin/warnlog"

# Copy everything over from the base image. This flattens the image a little
FROM scratch
COPY --from=build / /

LABEL TENANT.suite_parent.version="0.9"
LABEL vendor="Test"

# Setup evironment variables used by the standardized scripts
ARG TENANT_USER_ARG="stacey"
ARG CTX_BASE="."
ENV TENANT_USER="${TENANT_USER_ARG}"
ENV TENANT_HOME="/home/${TENANT_USER}"
ENV TENANT_CMD="${TENANT_HOME}/cmd"
ENV TENANT_RUN="${TENANT_CMD}/run"
ENV TENANT_SETUP="${TENANT_CMD}/setup"
ENV TENANT_TEARDOWN="${TENANT_CMD}/teardown"
ENV TENANT_STOP="${TENANT_CMD}/stop"
ENV TENANT_FINALLY="${TENANT_CMD}/finally"
ENV TENANT_INPUT="${TENANT_HOME}/input"
ENV TENANT_OUTPUT="${TENANT_HOME}/output"
ENV TENANT_OUTPUT_DIAGNOSTICS="${TENANT_OUTPUT}/diagnostic"
ENV TENANT_FRAMEWORK_LOG="${TENANT_OUTPUT}/TENANT_framework.log"
ENV TENANT_MESSAGE_LOG="${TENANT_OUTPUT}/messages.log"
ENV TENANT_WARNING_LOG="${TENANT_OUTPUT}/warnings.log"
ENV TENANT_ERROR_LOG="${TENANT_OUTPUT}/errors.log"
ENV SUITE_FAILURE_MESSAGE_FILE="${TENANT_OUTPUT}/suite-failure-message.txt"
ENV REGISTRY="stacey-1.localdomain:30003"
ENV TENANT_STOPPER_PORT="60106"

#RUN useradd -m -u 10000 -U -s /bin/bash "${TENANT_USER}" \
RUN mkdir -p "${TENANT_HOME}" \
    && mkdir -p "${TENANT_INPUT}" \
    && mkdir -p "${TENANT_OUTPUT}" \
    && mkdir -p "${TENANT_OUTPUT_DIAGNOSTICS}"

COPY "${CTX_BASE}"/"standardized_scripts/" "${TENANT_HOME}/"

#RUN chown -R "${TENANT_USER}": "${TENANT_HOME}" \
RUN     chmod +x "${TENANT_HOME}/invoke.sh" \
    && chmod +x "${TENANT_HOME}/run.sh" \
    && chmod +x "${TENANT_HOME}/setup.sh" \
    && chmod +x "${TENANT_HOME}/teardown.sh" \
    && chmod +x "${TENANT_HOME}/stop.sh" \
    && chmod +x "${TENANT_HOME}/stop_listener.sh" \
    && chmod +x "${TENANT_HOME}/finally.sh" \
  #  && chown "${TENANT_USER}": "${TENANT_INPUT}" \
  #  && chown "${TENANT_USER}": "${TENANT_OUTPUT}" \
  #  && chown "${TENANT_USER}": "${TENANT_OUTPUT_DIAGNOSTICS}"
