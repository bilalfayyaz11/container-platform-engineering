# Docker Compose Network Isolation

## Overview

This implementation demonstrates a secure multi-tier application architecture using Docker Compose custom bridge networks.

The environment runs an Nginx reverse proxy, a Python API, PostgreSQL, and Redis. Only Nginx is exposed to the host. The API connects the application tier to the isolated data tier, while PostgreSQL and Redis remain inaccessible from both the host and the proxy.

## Architecture

```text
Client
  |
  v
Nginx Proxy
  |
  +---------------- frontend-net
  |
  +---------------- backend-net
                         |
                         v
                       API
                         |
                         +------------- data-net
                                          |
                                 +--------+--------+
                                 |                 |
                            PostgreSQL           Redis
````

## Network Topology

| Service    | Networks                  | Host Exposure  |
| ---------- | ------------------------- | -------------- |
| Nginx      | frontend-net, backend-net | 127.0.0.1:8080 |
| API        | backend-net, data-net     | None           |
| PostgreSQL | data-net                  | None           |
| Redis      | data-net                  | None           |

Custom subnets:

```text
frontend-net: 172.30.10.0/24
backend-net:  172.30.20.0/24
data-net:     172.30.30.0/24
```

## Core Capabilities

* Explicit network segmentation
* Docker embedded DNS service discovery
* Nginx reverse-proxy routing
* PostgreSQL persistent storage
* Redis cache-aside behavior
* Health-aware dependency startup
* Non-root API runtime
* File-based runtime secrets
* Runtime network partition testing
* Degraded dependency health reporting
* Recovery without container restart
* Proxy-to-data isolation validation
* Reusable network operations automation

## Technology Stack

* Docker Engine
* Docker Compose
* Docker Buildx
* Python
* Flask
* Gunicorn
* PostgreSQL
* Redis
* Nginx
* Shell scripting

## Repository Structure

```text
compose-network-isolation/
├── compose.yaml
├── .env.example
├── .gitignore
├── README.md
├── api/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── app.py
│   ├── bootstrap.py
│   ├── cache.py
│   ├── health.py
│   ├── store.py
│   └── requirements.txt
├── nginx/
│   └── nginx.conf
└── scripts/
    └── network-operations.sh
```

Runtime credentials, local environment values, reports, and generated network inspection files are excluded from version control.

## Local Setup

Create the local environment file:

```bash
cp .env.example .env
```

Create runtime secrets:

```bash
mkdir -p secrets
chmod 700 secrets

openssl rand -hex 24 > secrets/postgres-password.txt
openssl rand -hex 24 > secrets/redis-password.txt

sudo chown root:10001 \
  secrets/postgres-password.txt \
  secrets/redis-password.txt

sudo chmod 0640 \
  secrets/postgres-password.txt \
  secrets/redis-password.txt
```

## Validate and Deploy

```bash
docker compose --file compose.yaml config

docker compose \
  --file compose.yaml \
  up \
  --detach \
  --build
```

Check service status:

```bash
docker compose \
  --file compose.yaml \
  ps \
  --all
```

## Test the Application

Check dependency health:

```bash
curl --fail http://127.0.0.1:8080/health | jq
```

List stored items:

```bash
curl --fail http://127.0.0.1:8080/items | jq
```

Create an item:

```bash
curl --fail \
  --request POST \
  --header 'Content-Type: application/json' \
  --data '{"name":"network-isolation-test"}' \
  http://127.0.0.1:8080/items | jq
```

## Validate Network Isolation

Confirm the proxy can reach the API:

```bash
docker compose exec proxy \
  wget -qO- http://api:5000/health
```

Confirm the API can resolve PostgreSQL and Redis:

```bash
docker compose exec api getent hosts db
docker compose exec api getent hosts cache
```

Confirm the proxy cannot resolve PostgreSQL or Redis:

```bash
docker compose exec proxy getent hosts db
docker compose exec proxy getent hosts cache
```

Both commands should fail because the proxy is not connected to the data network.

Confirm only Nginx publishes a host port:

```bash
docker port network-proxy
docker port network-db
docker port network-cache
```

The PostgreSQL and Redis commands should return no output.

## Inspect Networks

```bash
docker network inspect compose-frontend-net
docker network inspect compose-backend-net
docker network inspect compose-data-net
```

Containers use Docker's embedded DNS resolver:

```text
127.0.0.11
```

## Network Partition Test

Get the API container ID:

```bash
API_CONTAINER=$(
  docker compose \
    --file compose.yaml \
    ps \
    --quiet \
    api
)
```

Disconnect the API from the data network:

```bash
docker network disconnect \
  compose-data-net \
  "$API_CONTAINER"
```

The health endpoint should return a degraded non-200 response:

```bash
curl \
  --silent \
  --write-out '\nHTTP_STATUS:%{http_code}\n' \
  http://127.0.0.1:8080/health
```

Reconnect the API:

```bash
docker network connect \
  --ip 172.30.30.20 \
  compose-data-net \
  "$API_CONTAINER"
```

Verify recovery:

```bash
curl --fail http://127.0.0.1:8080/health | jq
```

The API recovers without being restarted or replaced.

## Operations Script

```bash
./scripts/network-operations.sh status
./scripts/network-operations.sh start
./scripts/network-operations.sh stop
./scripts/network-operations.sh restart
./scripts/network-operations.sh logs
./scripts/network-operations.sh inspect
./scripts/network-operations.sh disconnect-data
./scripts/network-operations.sh reconnect-data
./scripts/network-operations.sh down
```

## Security and Reliability

* API runs as UID and GID `10001`
* PostgreSQL and Redis have no host port bindings
* Backend and data networks are internal
* Credentials are mounted from ignored secret files
* API and proxy use `no-new-privileges`
* API uses a read-only filesystem
* PostgreSQL and Redis use persistent named volumes
* Healthchecks control dependency startup
* Dependency failures produce observable degraded responses
* Network connectivity can recover without restarting containers

## Skills Demonstrated

* Docker Compose architecture
* Container network segmentation
* Embedded DNS service discovery
* Reverse-proxy routing
* PostgreSQL integration
* Redis caching
* Persistent storage
* Healthchecks and dependency gates
* Container hardening
* Runtime failure injection
* Recovery validation
* Docker-native diagnostics
* Shell automation

## Cleanup

Remove containers and networks while retaining persistent data:

```bash
docker compose \
  --file compose.yaml \
  down \
  --remove-orphans
```

Remove persistent data only when it is no longer required:

```bash
docker volume rm \
  compose-postgres-data \
  compose-redis-data
```
