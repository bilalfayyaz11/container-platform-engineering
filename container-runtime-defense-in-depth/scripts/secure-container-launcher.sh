#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-container-security-runtime:1.0.0}"
shift || true

WORKDIR="${CONTAINER_SECURITY_WORKDIR:-$HOME/container-security-engineering}"
SECCOMP_PROFILE="$WORKDIR/seccomp/runtime-restricted.json"
APPARMOR_PROFILE="container-security-runtime"

test -f "$SECCOMP_PROFILE" || {
  echo "Missing seccomp profile: $SECCOMP_PROFILE"
  exit 1
}

docker image inspect "$IMAGE" >/dev/null

docker run --rm \
  --security-opt "seccomp=$SECCOMP_PROFILE" \
  --security-opt "apparmor=$APPARMOR_PROFILE" \
  --security-opt no-new-privileges:true \
  --user 10001:10001 \
  --cap-drop ALL \
  --memory 128m \
  --memory-swap 128m \
  --cpus 0.50 \
  --pids-limit 64 \
  --ulimit nofile=1024:1024 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=32m \
  "$IMAGE" \
  "$@"
