#!/usr/bin/env bash

set -Eeuo pipefail

CONTAINER_NAME="${1:-container-delivery-api-production}"

if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Container not found: $CONTAINER_NAME"
  exit 1
fi

echo "===== CONTAINER STATUS ====="
docker ps -a \
  --filter "name=^/${CONTAINER_NAME}$" \
  --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo
echo "===== HEALTH STATUS ====="
docker inspect \
  --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}No health check{{end}}' \
  "$CONTAINER_NAME"

echo
echo "===== RESOURCE USAGE ====="
docker stats --no-stream \
  --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
  "$CONTAINER_NAME"

echo
echo "===== RECENT LOGS ====="
docker logs --tail 30 "$CONTAINER_NAME"
