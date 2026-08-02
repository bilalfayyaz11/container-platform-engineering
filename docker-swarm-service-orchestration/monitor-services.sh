#!/usr/bin/env bash

set -u

echo "===== DOCKER SWARM STATUS ====="
docker info --format 'Swarm: {{.Swarm.LocalNodeState}} | Control available: {{.Swarm.ControlAvailable}}'
echo

echo "===== NODE INFORMATION ====="
docker node ls
echo

echo "===== STACK INFORMATION ====="
docker stack ls
echo

echo "===== SERVICE STATUS ====="
docker service ls
echo

echo "===== SERVICE TASK DETAILS ====="
for service in $(docker service ls --format '{{.Name}}'); do
    echo "--- Service: $service ---"
    docker service ps "$service" \
      --format 'table {{.Name}}\t{{.Image}}\t{{.Node}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}'
    echo
done

echo "===== CONTAINER RESOURCE USAGE ====="
docker stats --no-stream \
  --format 'table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'
