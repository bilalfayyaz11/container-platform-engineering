#!/usr/bin/env bash
set -Eeuo pipefail

WORKDIR="$HOME/compose-network-isolation"
COMPOSE_FILE="$WORKDIR/compose.yaml"
ACTION="${1:-}"

case "$ACTION" in
  status)
    docker compose --file "$COMPOSE_FILE" ps --all
    ;;

  start)
    docker compose --file "$COMPOSE_FILE" up --detach
    ;;

  stop)
    docker compose --file "$COMPOSE_FILE" stop
    ;;

  restart)
    docker compose --file "$COMPOSE_FILE" restart
    ;;

  logs)
    docker compose --file "$COMPOSE_FILE" logs --follow --tail 100
    ;;

  inspect)
    docker network inspect compose-frontend-net
    docker network inspect compose-backend-net
    docker network inspect compose-data-net
    ;;

  disconnect-data)
    API_CONTAINER=$(
      docker compose \
        --file "$COMPOSE_FILE" \
        ps \
        --quiet \
        api
    )

    docker network disconnect \
      compose-data-net \
      "$API_CONTAINER"
    ;;

  reconnect-data)
    API_CONTAINER=$(
      docker compose \
        --file "$COMPOSE_FILE" \
        ps \
        --quiet \
        api
    )

    docker network connect \
      --ip 172.30.30.20 \
      compose-data-net \
      "$API_CONTAINER"
    ;;

  down)
    docker compose \
      --file "$COMPOSE_FILE" \
      down \
      --remove-orphans
    ;;

  *)
    echo "Usage: $0 {status|start|stop|restart|logs|inspect|disconnect-data|reconnect-data|down}"
    exit 1
    ;;
esac
