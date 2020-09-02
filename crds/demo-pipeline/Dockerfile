# Copyright 2019 AT&T Intellectual Property.  All other rights reserved.
ARG FROM=lachlanevenson/k8s-kubectl:latest
FROM ${FROM} as build

ARG CTX_BASE="."

# Copy everything over from the base image. This flattens the image a little
FROM scratch
COPY --from=build / /

# Setup evironment variables used by the standardized scripts
ARG TENANT_USER="ubuntu"
ENV TENANT_HOME="/home/${TENANT_USER}"

ENV REGISTRY="stacey-0.localdomain:30003"

#RUN useradd -m -u 10000 -U -s /bin/bash "${TENANT_USER}" \
RUN mkdir -p "${TENANT_HOME}"

COPY "./standardized_scripts/*.sh" "${TENANT_HOME}/"
