#!/usr/bin/env bash
set -Eeuo pipefail

LABEL="${1:-debugging.scope=container-debugging-engineering}"
REPORT_DIR="${2:-$HOME/container-debugging-engineering/reports/triage}"

mkdir -p "$REPORT_DIR"

mapfile -t containers < <(
  docker ps -a \
    --filter "label=$LABEL" \
    --format '{{.Names}}' |
    sort
)

if [ "${#containers[@]}" -eq 0 ]; then
  echo "No containers found for label: $LABEL"
  exit 1
fi

for container in "${containers[@]}"; do
  safe_name=$(
    printf '%s' "$container" |
      tr -c '[:alnum:]_.-' '_'
  )

  "$HOME/container-debugging-engineering/scripts/debug-container.sh" \
    "$container" \
    "$REPORT_DIR/${safe_name}.txt"
done

echo "Generated ${#containers[@]} diagnostic reports in:"
echo "$REPORT_DIR"
