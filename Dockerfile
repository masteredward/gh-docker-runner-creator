FROM debian:stable-slim

ARG RUNNER_VERSION
ARG TARGETARCH
ARG OWNER_UID
ARG DOCKER_GID

ENV DEBIAN_FRONTEND=noninteractive

RUN if [ -z "$RUNNER_VERSION" ] || [ -z "$TARGETARCH" ] || [ -z "$OWNER_UID" ] || [ -z "$DOCKER_GID" ]; then \
      echo "Error: RUNNER_VERSION, TARGETARCH, OWNER_UID and DOCKER_GID must be provided"; exit 1; \
    fi

RUN apt update \
    && apt install -y curl unzip \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update \
    && apt install docker-ce-cli -y \
    && rm -rf /var/lib/apt/lists/*

# Install to a different directory that won't be mounted
WORKDIR /runner-installation

RUN DOWNLOAD_ARCH=$(if [ "$TARGETARCH" = "amd64" ]; then echo "x64"; else echo "$TARGETARCH"; fi) \
    && curl -o actions-runner-linux-${DOWNLOAD_ARCH}-${RUNNER_VERSION}.tar.gz -L \
        https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${DOWNLOAD_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf actions-runner-linux-${DOWNLOAD_ARCH}-${RUNNER_VERSION}.tar.gz \
    && rm actions-runner-linux-${DOWNLOAD_ARCH}-${RUNNER_VERSION}.tar.gz \
    && ./bin/installdependencies.sh \
    && groupadd -g ${DOCKER_GID} docker \
    && useradd runner -m -u ${OWNER_UID} -G docker \
    && mkdir -p /actions-runner \
    && chown -R runner:runner /runner-installation /actions-runner

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER runner

ENTRYPOINT ["/entrypoint.sh"]
