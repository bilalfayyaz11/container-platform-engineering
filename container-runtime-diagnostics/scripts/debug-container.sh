#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: $0 <container-name> [output-file]"
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

CONTAINER="$1"
OUTPUT_FILE="${2:-}"

if ! docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "Container not found: $CONTAINER"
  exit 1
fi

generate_report() {
  echo "Container Diagnostic Report"
  echo "==========================="
  echo "Container: $CONTAINER"
  echo "Generated: $(date -Iseconds)"
  echo

  echo "STATUS"
  docker ps -a \
    --filter "name=^/${CONTAINER}$" \
    --format 'Name={{.Names}} Image={{.Image}} Status={{.Status}} Ports={{.Ports}}'
  echo

  echo "STATE"
  docker inspect "$CONTAINER" \
    --format 'Status={{.State.Status}} Running={{.State.Running}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Restarting={{.State.Restarting}} RestartCount={{.RestartCount}} Error={{.State.Error}}'
  echo

  echo "TIMESTAMPS"
  docker inspect "$CONTAINER" \
    --format 'Created={{.Created}} Started={{.State.StartedAt}} Finished={{.State.FinishedAt}}'
  echo

  echo "IMAGE AND COMMAND"
  docker inspect "$CONTAINER" \
    --format 'Image={{.Config.Image}} Entrypoint={{json .Config.Entrypoint}} Command={{json .Config.Cmd}} WorkingDir={{.Config.WorkingDir}} User={{.Config.User}}'
  echo

  echo "RESOURCE LIMITS"
  docker inspect "$CONTAINER" \
    --format 'Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}} NanoCPUs={{.HostConfig.NanoCpus}} CpuShares={{.HostConfig.CpuShares}} PidsLimit={{.HostConfig.PidsLimit}}'
  echo

  echo "SECURITY"
  docker inspect "$CONTAINER" \
    --format 'Privileged={{.HostConfig.Privileged}} ReadOnly={{.HostConfig.ReadonlyRootfs}} CapAdd={{json .HostConfig.CapAdd}} CapDrop={{json .HostConfig.CapDrop}} SecurityOptions={{json .HostConfig.SecurityOpt}}'
  echo

  echo "RESTART AND LOGGING"
  docker inspect "$CONTAINER" \
    --format 'RestartPolicy={{.HostConfig.RestartPolicy.Name}} LogDriver={{.HostConfig.LogConfig.Type}}'
  echo

  echo "PORTS"
  docker inspect "$CONTAINER" \
    --format '{{json .NetworkSettings.Ports}}' |
    python3 -m json.tool
  echo

  echo "NETWORKS"
  docker inspect "$CONTAINER" \
    --format '{{json .NetworkSettings.Networks}}' |
    python3 -m json.tool
  echo

  echo "MOUNTS"
  docker inspect "$CONTAINER" \
    --format '{{json .Mounts}}' |
    python3 -m json.tool
  echo

  echo "ENVIRONMENT — REDACTED"
  docker inspect "$CONTAINER" \
    --format '{{range .Config.Env}}{{println .}}{{end}}' |
    sed -E \
      's/^(([^=]*(PASSWORD|PASSWD|TOKEN|SECRET|API_KEY|PRIVATE_KEY|ACCESS_KEY)[^=]*)=).*/\1[REDACTED]/I'
  echo

  echo "RECENT LOGS"
  docker logs \
    --timestamps \
    --tail 30 \
    "$CONTAINER" 2>&1 || true
  echo

  if [ "$(docker inspect "$CONTAINER" --format '{{.State.Running}}')" = "true" ]; then
    echo "RESOURCE SNAPSHOT"
    docker stats "$CONTAINER" \
      --no-stream \
      --format 'CPU={{.CPUPerc}} Memory={{.MemUsage}} MemoryPercent={{.MemPerc}} Network={{.NetIO}} Block={{.BlockIO}} PIDs={{.PIDs}}'
    echo

    echo "PROCESS SNAPSHOT"
    docker top "$CONTAINER" || true
    echo
  else
    echo "RESOURCE SNAPSHOT"
    echo "Container is not running; live statistics unavailable."
    echo
  fi

  echo "DIAGNOSTIC HINTS"

  STATUS=$(docker inspect "$CONTAINER" --format '{{.State.Status}}')
  EXIT_CODE=$(docker inspect "$CONTAINER" --format '{{.State.ExitCode}}')
  ERROR_TEXT=$(docker inspect "$CONTAINER" --format '{{.State.Error}}')
  OOM_KILLED=$(docker inspect "$CONTAINER" --format '{{.State.OOMKilled}}')

  if [ -n "$ERROR_TEXT" ]; then
    echo "- Runtime error recorded: $ERROR_TEXT"
  fi

  if [ "$STATUS" = "exited" ] || [ "$STATUS" = "created" ]; then
    echo "- Container is not running; inspect command, entrypoint, logs, and exit code."
  fi

  if [ "$EXIT_CODE" -eq 127 ]; then
    echo "- Exit code 127 usually means the command or executable was not found."
  fi

  if [ "$OOM_KILLED" = "true" ]; then
    echo "- Container was terminated by the kernel memory controller."
  fi

  echo
  echo "END OF REPORT"
}

if [ -n "$OUTPUT_FILE" ]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  generate_report | tee "$OUTPUT_FILE"
else
  generate_report
fi
