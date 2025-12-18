# -----------------------------------------------------------
# Base image
# -----------------------------------------------------------
FROM debian:stable-slim
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/root \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

WORKDIR /root

# -----------------------------------------------------------
# Install base dependencies
# -----------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    jq \
    ca-certificates \
    coreutils \
    moreutils \
    tzdata \
    openssh-client \
    sshpass \
 && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------
# Install IBM Cloud CLI
# -----------------------------------------------------------
RUN curl -fsSL https://clis.cloud.ibm.com/install/linux | bash

ENV PATH="/usr/local/ibmcloud/bin:/root/.bluemix:$PATH"

# -----------------------------------------------------------
# Configure IBM Cloud CLI
# -----------------------------------------------------------
RUN ibmcloud config --check-version=false

# -----------------------------------------------------------
# Install required IBM Cloud plugins
# (PowerVS only – Code Engine plugin not needed in a CE job)
# -----------------------------------------------------------
RUN ibmcloud plugin install power-iaas -f

# -----------------------------------------------------------
# Copy job script
# -----------------------------------------------------------
COPY job2.5-clone-ops.sh /job2.5-clone-ops.sh

RUN sed -i 's/\r$//' /job2.5-clone-ops.sh && \
    chmod 750 /job2.5-clone-ops.sh

# -----------------------------------------------------------
# Runtime
# -----------------------------------------------------------
ENTRYPOINT ["/job2.5-clone-ops.sh"]
