FROM alpine:latest

LABEL org.opencontainers.image.title="Container Diagnostic Toolkit"
LABEL org.opencontainers.image.description="Ephemeral network and process troubleshooting image"

RUN apk add --no-cache \
      bash \
      bind-tools \
      busybox-extras \
      curl \
      iproute2 \
      iputils \
      jq \
      netcat-openbsd \
      procps \
      strace \
      tcpdump

WORKDIR /diagnostics

USER 65534:65534

ENTRYPOINT ["/bin/bash"]
