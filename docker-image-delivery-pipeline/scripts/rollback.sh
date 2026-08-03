#!/usr/bin/env bash

set -Eeuo pipefail

DOCKER_USERNAME="${1:?Usage: rollback.sh DOCKER_USERNAME PREVIOUS_TAG [PORT]}"
PREVIOUS_TAG="${2:?Previous image tag is required}"
PORT="${3:-8080}"
IMAGE="${DOCKER_USERNAME}/container-delivery-api:${PREVIOUS_TAG}"
CONTAINER_NAME="container-delivery-api-production"
ENV_FILE="config/environments/production.env"

echo "Rolling back production to ${IMAGE}"

docker pull "$IMAGE"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart always \
  --publish "${PORT}:3000" \
  --env-file "$ENV_FILE" \
  "$IMAGE"

for attempt in $(seq 1 30); do
  STATUS=$(docker inspect \
    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}unavailable{{end}}' \
    "$CONTAINER_NAME" 2>/dev/null || true)

  echo "Attempt ${attempt}: ${STATUS:-starting}"

  if [ "$STATUS" = "healthy" ]; then
    echo "Rollback verified"
    exit 0
  fi

  sleep 2
done

docker logs "$CONTAINER_NAME"
exit 1
