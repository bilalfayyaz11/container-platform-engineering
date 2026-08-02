#!/usr/bin/env bash
set -Eeuo pipefail

WORKDIR="$HOME/container-build-engineering"
GO_DIR="$WORKDIR/go-service"
REPORT_DIR="$WORKDIR/reports"
METRIC_DIR="$WORKDIR/metrics"
BUILDER="engineering-builder"

mkdir -p "$REPORT_DIR" "$METRIC_DIR"

cd "$GO_DIR"

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
    >> "$METRIC_DIR/go-build-times.csv"

  echo "$label: ${elapsed_ms} ms"
}

echo 'build,elapsed_ms' \
  > "$METRIC_DIR/go-build-times.csv"

measure_build \
  go-single-stage \
  docker build \
    --no-cache \
    --file Dockerfile.single-stage \
    --tag go-build:single-stage \
    .

measure_build \
  go-multistage-cold \
  docker buildx build \
    --builder "$BUILDER" \
    --no-cache \
    --load \
    --progress plain \
    --file Dockerfile \
    --tag go-build:optimized \
    .

measure_build \
  go-multistage-cached \
  docker buildx build \
    --builder "$BUILDER" \
    --load \
    --progress plain \
    --file Dockerfile \
    --tag go-build:optimized-cached \
    .

sed -i \
  's/container-build-go-service/container-build-go-service-updated/' \
  main.go

measure_build \
  go-source-change \
  docker buildx build \
    --builder "$BUILDER" \
    --load \
    --progress plain \
    --file Dockerfile \
    --tag go-build:source-change \
    .

sed -i \
  's/container-build-go-service-updated/container-build-go-service/' \
  main.go
