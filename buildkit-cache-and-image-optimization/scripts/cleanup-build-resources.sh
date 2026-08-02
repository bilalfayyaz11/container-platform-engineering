#!/usr/bin/env bash
set -Eeuo pipefail

WORKDIR="$HOME/container-build-engineering"

echo "Removing scoped containers..."

docker ps -aq \
  --filter label=build.scope=container-build-engineering |
  xargs -r docker rm -f

docker compose \
  --file "$WORKDIR/compose.yaml" \
  down \
  --remove-orphans \
  2>/dev/null || true

echo "Removing scoped images..."

docker images \
  --format '{{.Repository}}:{{.Tag}}' |
  grep -E '^(node-build|go-build):' |
  xargs -r docker image rm -f

echo "Removing dedicated builders..."

docker buildx rm \
  engineering-builder \
  cache-validation-builder \
  2>/dev/null || true

echo "Removing dedicated network..."

docker network rm \
  container-build-network \
  2>/dev/null || true

echo "Cleanup complete."
