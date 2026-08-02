# Docker Swarm Service Orchestration

## What This Does

This implementation deploys replicated Nginx and Redis services using Docker Swarm and Docker Stack. It demonstrates service scaling, ingress routing, rolling updates, placement constraints, resource limits, health checks, monitoring, log collection, and complete service lifecycle management.

## Architecture

    Client Requests
          |
          v
    Docker Swarm Ingress :8080
          |
          v
    Overlay Network
       |          |
       v          v
    Nginx      Nginx
    Replica    Replica
          |
          v
        Redis

    Operational Controls
    ├── Replica scaling
    ├── Rolling updates
    ├── Health checks
    ├── Resource limits
    ├── Placement constraints
    ├── Service monitoring
    └── Log collection

## Prerequisites

- Linux
- Docker Engine
- Docker Compose plugin
- Git
- curl
- wget
- Available ports 8080 and 8081
- Docker daemon access for the current user

## Setup

Verify Docker:

```bash
docker --version
docker compose version
docker info
```

Initialize Swarm mode:

```bash
MANAGER_IP=$(hostname -I | awk '{print $1}')
docker swarm init --advertise-addr "$MANAGER_IP"
```

## How to Reproduce

Clone the repository:

```bash
git clone https://github.com/bilalfayyaz11/container-platform-engineering.git
cd container-platform-engineering/docker-swarm-service-orchestration
```

Deploy the main stack:

```bash
docker stack deploy --detach=true \
  -c services/web-stack.yml \
  webstack
```

Verify the deployment:

```bash
docker stack services webstack
docker service ps webstack_web
docker service ps webstack_redis
curl --fail http://127.0.0.1:8080
```

Scale the web service:

```bash
docker service scale webstack_web=4
docker service ps webstack_web
docker service scale webstack_web=2
```

Deploy the health-check stack:

```bash
docker stack deploy --detach=true \
  -c services/health-check-stack.yml \
  healthstack

docker service ps healthstack_web-with-health
curl --fail http://127.0.0.1:8081
```

Run monitoring and log collection:

```bash
./monitor-services.sh
./collect-logs.sh
```

Clean up:

```bash
docker stack rm webstack
docker stack rm healthstack
docker service rm constrained-service 2>/dev/null || true
docker service rm resource-limited 2>/dev/null || true
docker swarm leave --force
```

## Tools Used

- Docker Engine
- Docker Swarm
- Docker Stack
- Docker Compose
- Nginx
- Redis
- Bash
- YAML
- Linux
- curl
- Git

## Key Skills Demonstrated

- Container orchestration with Docker Swarm
- Declarative multi-service deployments
- Horizontal service scaling
- Rolling service updates
- Overlay networking and ingress routing
- Placement constraints and node labels
- CPU and memory governance
- Container health checks
- Service monitoring and log collection
- Runtime troubleshooting and cleanup

## Real-World Use Case

This design can support internal platforms, edge services, lightweight APIs, and smaller production environments that need replicated containers, controlled updates, resource governance, and operational visibility without the complexity of a larger orchestration platform.

## Lessons Learned

- Docker CLI installation does not guarantee Docker daemon access.
- Swarm initialization should use an explicit advertised address on cloud hosts.
- Bind-mounted content must exist on every node eligible to run the service.
- Updating a file does not automatically trigger task replacement.
- `$HOME` should be used instead of a quoted `~` inside shell scripts.
- Single-node Swarm validates orchestration behavior but not node-level high availability.

## Troubleshooting Log

### Docker daemon access

The current user was added to the Docker group:

```bash
sudo usermod -aG docker "$USER"
```

### Swarm manager address

An explicit private address prevented Docker from selecting the wrong interface:

```bash
docker swarm init --advertise-addr "$(hostname -I | awk '{print $1}')"
```

### Static content mount

The Nginx service uses the actual host content directory:

```yaml
volumes:
  - type: bind
    source: /home/ubuntu/docker-swarm-orchestration/web-content
    target: /usr/share/nginx/html
    read_only: true
```

### Rolling update

A forced service update recreated tasks using the configured rollout policy:

```bash
docker service update \
  --update-parallelism 1 \
  --update-delay 5s \
  --update-order start-first \
  --force \
  webstack_web
```

### Log directory path

The log collector uses:

```bash
LOG_DIR="$HOME/docker-swarm-orchestration/logs"
```
