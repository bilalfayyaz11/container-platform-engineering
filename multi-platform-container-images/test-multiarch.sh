#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE="bilalfayyaz11/multi-platform-runtime-api:latest"

echo "Testing $IMAGE"

echo "===== AMD64 ====="
docker run --rm   --platform linux/amd64   "$IMAGE"   node -e "console.log({
    platform: process.platform,
    architecture: process.arch,
    nodeVersion: process.version
  })"

echo "===== ARM64 ====="
docker run --rm   --platform linux/arm64   "$IMAGE"   node -e "console.log({
    platform: process.platform,
    architecture: process.arch,
    nodeVersion: process.version
  })"
