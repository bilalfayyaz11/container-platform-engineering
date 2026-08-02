#!/usr/bin/env bash
set -Eeuo pipefail

IMAGES=(
  "container-image-optimization:baseline"
  "container-image-optimization:optimized"
  "container-image-optimization:1.0.0"
)

printf "%-45s %-12s %-8s %-12s\n" \
  "IMAGE" "SIZE" "LAYERS" "USER"

for image in "${IMAGES[@]}"; do
  size=$(docker images "$image" --format '{{.Size}}')
  layers=$(docker image inspect "$image" --format '{{len .RootFS.Layers}}')
  user=$(docker image inspect "$image" --format '{{.Config.User}}')

  printf "%-45s %-12s %-8s %-12s\n" \
    "$image" "$size" "$layers" "${user:-root}"
done
