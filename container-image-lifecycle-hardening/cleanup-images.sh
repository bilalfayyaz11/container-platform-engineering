#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== BEFORE CLEANUP ====="
docker system df

docker container prune --force

docker image prune \
  --force \
  --filter "until=24h"

docker builder prune \
  --force \
  --filter "until=24h"

echo
echo "===== AFTER CLEANUP ====="
docker system df
