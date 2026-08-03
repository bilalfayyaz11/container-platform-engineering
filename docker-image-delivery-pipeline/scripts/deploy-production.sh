#!/usr/bin/env bash

set -Eeuo pipefail

DOCKER_USERNAME="${1:?Usage: deploy-production.sh DOCKER_USERNAME [IMAGE_TAG] [PORT]}"
IMAGE_TAG="${2:-latest}"
PORT="${3:-8080}"
IMAGE="${DOCKER_USERNAME}/container-delivery-api:${IMAGE_TAG}"
CONTAINER_NAME="container-delivery-api-production"
ENV_FILE="config/environments/production.env"

echo "Deploying ${IMAGE} to production"

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
    curl --fail --silent "http://127.0.0.1:${PORT}/health"
    echo
    echo "Production deployment verified"
    exit 0
  fi

  sleep 2
done

docker logs "$CONTAINER_NAME"
exit 1
