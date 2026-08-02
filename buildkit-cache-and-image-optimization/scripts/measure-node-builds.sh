#!/usr/bin/env bash
set -Eeuo pipefail

WORKDIR="$HOME/container-build-engineering"
NODE_DIR="$WORKDIR/node-service"
METRIC_DIR="$WORKDIR/metrics"
REPORT_DIR="$WORKDIR/reports"
BUILDER="engineering-builder"

mkdir -p "$METRIC_DIR" "$REPORT_DIR"

cd "$NODE_DIR"

measure_build() {
  local label="$1"
  shift

  local start_ns
  local end_ns
  local elapsed_ms

  start_ns=$(date +%s%N)

  "$@" \
    > "$REPORT_DIR/${label}.log" \
    2>&1

  end_ns=$(date +%s%N)
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))

  printf '%s,%s\n' \
    "$label" \
    "$elapsed_ms" \
    >> "$METRIC_DIR/node-build-times.csv"

  echo "$label: ${elapsed_ms} ms"
}

echo 'build,elapsed_ms' \
  > "$METRIC_DIR/node-build-times.csv"

docker buildx prune \
  --builder "$BUILDER" \
  --all \
  --force \
  >/dev/null 2>&1 || true

measure_build \
  traditional-cold \
  docker build \
    --no-cache \
    --file Dockerfile.traditional \
    --tag node-build:traditional \
    .

measure_build \
  buildkit-cold \
  docker buildx build \
    --builder "$BUILDER" \
    --no-cache \
    --load \
    --progress plain \
    --file Dockerfile \
    --tag node-build:optimized \
    .

measure_build \
  buildkit-cached \
  docker buildx build \
    --builder "$BUILDER" \
    --load \
    --progress plain \
    --file Dockerfile \
    --tag node-build:optimized-cached \
    .

sed -i \
  's/BuildKit cache optimization is active/BuildKit source-layer cache invalidation test/' \
  server.js

measure_build \
  buildkit-source-change \
  docker buildx build \
    --builder "$BUILDER" \
    --load \
    --progress plain \
    --file Dockerfile \
    --tag node-build:source-change \
    .

sed -i \
  's/BuildKit source-layer cache invalidation test/BuildKit cache optimization is active/' \
  server.js
