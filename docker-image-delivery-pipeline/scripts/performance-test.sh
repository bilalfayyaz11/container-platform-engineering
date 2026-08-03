#!/usr/bin/env bash

set -Eeuo pipefail

TARGET_URL="${1:-http://127.0.0.1:3001}"
REQUESTS="${2:-500}"
CONCURRENCY="${3:-20}"

echo "Target: $TARGET_URL"
echo "Requests: $REQUESTS"
echo "Concurrency: $CONCURRENCY"

ab \
  -n "$REQUESTS" \
  -c "$CONCURRENCY" \
  "${TARGET_URL}/"

echo
echo "===== HEALTH ENDPOINT TEST ====="

ab \
  -n 100 \
  -c 10 \
  "${TARGET_URL}/health"
