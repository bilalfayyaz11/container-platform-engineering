#!/usr/bin/env bash
set -Eeuo pipefail

OUTPUT_FILE="${1:-container-metrics.csv}"
SAMPLES="${2:-5}"
INTERVAL="${3:-2}"

containers=(
  webserver-debug
  noisy-service
  debug-config
  debug-cpu-load
  debug-memory-load
)

echo 'timestamp,container,cpu_percent,memory_usage,memory_percent,network_io,block_io,pids' \
  > "$OUTPUT_FILE"

for ((sample = 1; sample <= SAMPLES; sample++)); do
  timestamp=$(date -Iseconds)

  docker stats \
    --no-stream \
    --format "${timestamp},{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" \
    "${containers[@]}" \
    >> "$OUTPUT_FILE"

  if [ "$sample" -lt "$SAMPLES" ]; then
    sleep "$INTERVAL"
  fi
done
