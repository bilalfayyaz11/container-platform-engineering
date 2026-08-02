#!/usr/bin/env bash

set -u

LOG_DIR="$HOME/docker-swarm-orchestration/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR"

echo "Collecting service logs..."

for service in $(docker service ls --format '{{.Name}}'); do
    LOG_FILE="$LOG_DIR/${service}_${TIMESTAMP}.log"

    echo "Collecting logs for $service"

    docker service logs \
      --timestamps \
      --tail 100 \
      "$service" > "$LOG_FILE" 2>&1 || true
done

echo "Logs collected in: $LOG_DIR"
ls -lh "$LOG_DIR"
