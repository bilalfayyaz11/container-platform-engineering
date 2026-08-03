FROM ubuntu:22.04 AS builder

WORKDIR /build

COPY index.html start.sh ./

RUN chmod 0755 start.sh \
    && chmod 0444 index.html \
    && mkdir -p rootfs/app \
    && cp index.html rootfs/app/index.html \
    && cp start.sh rootfs/app/start.sh

FROM alpine:latest AS runtime

RUN apk add --no-cache busybox-extras \
    && addgroup -S -g 1001 securegroup \
    && adduser -S -D -H -u 1001 -G securegroup secureuser \
    && command -v httpd \
    && command -v wget

WORKDIR /app

COPY --from=builder --chown=1001:1001 /build/rootfs/app/ /app/

USER 1001:1001

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --quiet --timeout=2 --output-document=/dev/null http://127.0.0.1:8080/ || exit 1

ENTRYPOINT ["/app/start.sh"]
