# Dockerfile Optimization and Runtime Hardening

## What This Does

This implementation compares a basic container image with optimized multi-stage Node.js, TypeScript, and Python images.

It demonstrates image-size reduction, separation of build and runtime dependencies, non-root execution, application health checks, read-only filesystems, reduced Linux capabilities, and prevention of privilege escalation.

## Architecture

    Source Code
        |
        +-- Baseline Node.js Build
        |       |
        |       +-- Full Node.js Runtime Image
        |
        +-- TypeScript Source
        |       |
        |       +-- Builder Stage
        |               |
        |               +-- Compiled Output
        |                       |
        |                       +-- Minimal Non-Root Runtime
        |
        +-- Python Application
                |
                +-- Dependency Stage
                        |
                        +-- Hardened Gunicorn Runtime
                                |
                                +-- Health Check
                                +-- Read-Only Root Filesystem
                                +-- Dropped Capabilities
                                +-- No New Privileges

## Prerequisites

- Linux operating system
- Docker Engine
- Docker BuildKit and Buildx
- Git
- curl
- Available host ports: 3000, 3001, and 5000

Node.js, TypeScript, Python, Flask, and Gunicorn execute inside containers and are not required on the host.

## Setup and Installation

Verify the required tools:

    docker --version
    docker buildx version
    docker info
    git --version
    curl --version

If Docker access is denied:

    sudo usermod -aG docker "$USER"
    newgrp docker

Clone the repository:

    git clone https://github.com/bilalfayyaz11/container-platform-engineering.git
    cd container-platform-engineering/dockerfile-optimization-runtime-hardening

## How to Reproduce

### Build the Baseline Node.js Image

    cd simple-node

    docker build \
      --tag simple-node-app:v1 \
      .

Run and test the container:

    docker run --detach \
      --name simple-app \
      --publish 3000:3000 \
      simple-node-app:v1

    curl http://localhost:3000
    docker logs simple-app
    docker rm --force simple-app

### Build the Single-Stage TypeScript Image

    cd ../typescript-optimized

    docker build \
      --file Dockerfile.single-stage \
      --tag typescript-app:single-stage \
      .

### Build the Optimized Multi-Stage TypeScript Image

    docker build \
      --tag typescript-app:multi-stage \
      .

Run and validate the optimized image:

    docker run --detach \
      --name multi-stage-app \
      --publish 3001:3000 \
      typescript-app:multi-stage

    curl http://localhost:3001

    docker inspect multi-stage-app \
      --format '{{.State.Health.Status}}'

    docker exec multi-stage-app whoami
    docker exec multi-stage-app id
    docker rm --force multi-stage-app

### Build the Hardened Python Image

    cd ../flask-hardened

    docker build \
      --tag flask-app:advanced \
      .

Review the image history:

    docker history flask-app:advanced

Run with restrictive runtime controls:

    docker run --detach \
      --name flask-secure \
      --read-only \
      --tmpfs /tmp \
      --cap-drop ALL \
      --cap-add NET_BIND_SERVICE \
      --security-opt no-new-privileges \
      --publish 5000:5000 \
      flask-app:advanced

Validate the application:

    curl http://localhost:5000
    curl http://localhost:5000/health

Validate non-root execution:

    docker exec flask-secure whoami
    docker exec flask-secure id

Validate the health check:

    docker inspect flask-secure \
      --format '{{.State.Health.Status}}'

Validate read-only filesystem enforcement:

    docker exec flask-secure sh -c 'touch /test-file' \
      || echo "Read-only filesystem enforced"

Review resource consumption:

    docker stats flask-secure --no-stream

Remove the container:

    docker rm --force flask-secure

### Compare Image Sizes

    docker images \
      --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" |
      grep -E "simple-node-app|typescript-app|flask-app"

### Compare Layer Counts

    for image in \
      simple-node-app:v1 \
      typescript-app:single-stage \
      typescript-app:multi-stage \
      flask-app:advanced
    do
      echo "$image: $(docker history --quiet "$image" | wc -l) layers"
    done

## Tools Used

- Docker Engine
- Docker CLI
- Docker BuildKit
- Docker Buildx
- Node.js
- TypeScript
- npm
- Python
- Flask
- Gunicorn
- curl
- Linux capability controls

## Key Skills Demonstrated

- Multi-stage Dockerfile design
- Build and runtime dependency separation
- Container image-size optimization
- Production dependency pruning
- Non-root process execution
- Container-native health checks
- Read-only root filesystem enforcement
- Linux capability reduction
- Privilege-escalation prevention
- Image history and layer analysis
- Runtime security validation
- Repeatable application packaging

## Real-World Use Case

These practices are used when packaging APIs, microservices, automation services, internal platform components, and machine-learning inference endpoints.

Multi-stage builds keep compilers, source files, and development dependencies outside production images. Non-root users, health checks, read-only filesystems, dropped capabilities, and privilege restrictions reduce operational and security risk when images are deployed through Kubernetes, CI/CD pipelines, private registries, or managed container platforms.

## Lessons Learned

- Build tools and development dependencies should not be included in final runtime images.
- Multi-stage builds improve image efficiency, reproducibility, and security.
- Smaller runtime images reduce transfer time and attack surface.
- Non-root execution must be designed into the image.
- Read-only containers require explicit writable mounts for temporary files.
- Health checks must use commands available inside the final runtime image.
- Image size is only one measurement; identity, capabilities, filesystem permissions, and dependencies must also be reviewed.

## Troubleshooting Log

### Docker Socket Permission Failure

The current user initially lacked permission to access the Docker socket.

Resolution:

    sudo usermod -aG docker "$USER"
    newgrp docker

### Outdated Node.js Baseline

An older Node.js image was replaced with a current LTS image for new builds.

### Deprecated Production Dependency Syntax

The older command:

    npm install --only=production

was replaced with:

    npm install --omit=dev

This uses current npm syntax for excluding development dependencies.

### Outdated Python Baseline

The older Python Bullseye image was replaced with a current Python slim image.

### Read-Only Runtime Requirements

The hardened container uses:

    --read-only
    --tmpfs /tmp

The root filesystem remains immutable while `/tmp` provides controlled temporary writable storage.

### Health Check Initially Reports Starting

The application may require several seconds to start and complete its first health-check interval.

Check again with:

    docker inspect CONTAINER_NAME \
      --format '{{.State.Health.Status}}'

### Minimal Runtime Image Limitations

Minimal images may not include utilities such as `ps`, `curl`, or package managers. Validation should use Docker inspection, application endpoints, logs, and explicitly configured health checks.
