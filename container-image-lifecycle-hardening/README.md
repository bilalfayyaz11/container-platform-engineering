# Container Image Lifecycle and Runtime Hardening

## What This Does

This implementation demonstrates a complete container-image lifecycle, progressing from a large baseline Node.js image to optimized and security-hardened runtime variants.

It applies build-context filtering, deterministic dependency installation, multi-stage construction, semantic tagging, health checks, non-root execution, resource limits, read-only filesystems, dropped Linux capabilities, vulnerability scanning, image analysis, and controlled cleanup automation.

The implementation provides executable evidence for image size, layer count, configured runtime identity, application health, resource restrictions, and vulnerability posture.

## Architecture

    Application Source
           |
           v
    +---------------------+
    | Build Context       |
    |                     |
    | package.json        |
    | package-lock.json   |
    | server.js           |
    | .dockerignore       |
    +----------+----------+
               |
               +-----------------------------+
               |                             |
               v                             v
    +---------------------+       +----------------------+
    | Baseline Image      |       | Optimized Image      |
    |                     |       |                      |
    | Full Node Runtime   |       | Alpine Runtime       |
    | Broad COPY          |       | Filtered Context     |
    | Root Execution      |       | Non-Root User        |
    +----------+----------+       +----------+-----------+
               |                             |
               |                             v
               |                  +----------------------+
               |                  | Hardened Multi-Stage |
               |                  | Runtime              |
               |                  |                      |
               |                  | Production Packages  |
               |                  | dumb-init            |
               |                  | Health Check         |
               |                  | Non-Root User        |
               |                  +----------+-----------+
               |                             |
               +-----------------------------+
                                             |
                                             v
                                  +----------------------+
                                  | Runtime Validation   |
                                  |                      |
                                  | HTTP Endpoints       |
                                  | Health Status        |
                                  | Resource Limits      |
                                  | Read-Only Root FS    |
                                  | Vulnerability Scan   |
                                  | Layer Analysis       |
                                  +----------------------+

## Directory Structure

    container-image-lifecycle-hardening/
    ├── README.md
    ├── analyze-images.sh
    ├── cleanup-images.sh
    ├── node-service/
    │   ├── .dockerignore
    │   ├── Dockerfile
    │   ├── Dockerfile.baseline
    │   ├── Dockerfile.optimized
    │   ├── package.json
    │   ├── package-lock.json
    │   └── server.js
    └── reports/
        ├── image-analysis.txt
        └── trivy-report.txt

## Prerequisites

- Linux operating system
- Docker Engine
- Docker BuildKit and Buildx
- Git
- curl
- At least 2 GB of available disk space
- Available host ports `3000`, `3001`, and `3002`

Node.js and npm run inside container build stages and are not required on the host.

## Setup and Installation

Verify the required tools:

    docker --version
    docker buildx version
    docker info
    git --version
    curl --version

If Docker socket access is denied:

    sudo usermod -aG docker "$USER"
    newgrp docker

Clone the repository:

    git clone https://github.com/bilalfayyaz11/container-platform-engineering.git
    cd container-platform-engineering/container-image-lifecycle-hardening/node-service

## Image Variants

### Baseline

The baseline image uses a full Node.js runtime, copies the complete build context, installs dependencies with a general installation command, and runs with the default root identity.

### Optimized

The optimized image uses an Alpine runtime, deterministic dependency installation, a filtered build context, an application-specific non-root user, and a container-native health check.

### Hardened Multi-Stage

The hardened image separates dependency installation from the final runtime, includes only production requirements, uses `dumb-init` for signal handling, runs as a non-root user, and supports restrictive runtime controls.

## How to Reproduce

Generate or refresh the dependency lock file:

    docker run --rm \
      --user "$(id -u):$(id -g)" \
      --volume "$PWD:/app" \
      --workdir /app \
      node:lts-alpine \
      npm install --package-lock-only --ignore-scripts

Build the baseline image:

    docker build \
      --file Dockerfile.baseline \
      --tag container-image-optimization:baseline \
      .

Build the optimized image:

    docker build \
      --file Dockerfile.optimized \
      --tag container-image-optimization:optimized \
      .

Build the hardened multi-stage image:

    docker build \
      --file Dockerfile \
      --tag container-image-optimization:1.0.0 \
      --tag container-image-optimization:latest \
      .

## Runtime Validation

Run the baseline image:

    docker run --detach \
      --name image-baseline-test \
      --publish 3000:3000 \
      container-image-optimization:baseline

    curl http://localhost:3000/
    docker logs image-baseline-test
    docker rm --force image-baseline-test

Run the optimized image:

    docker run --detach \
      --name image-optimized-test \
      --publish 3001:3000 \
      container-image-optimization:optimized

    curl http://localhost:3001/
    curl http://localhost:3001/health

    docker exec image-optimized-test whoami

    docker inspect image-optimized-test \
      --format '{{.State.Health.Status}}'

    docker rm --force image-optimized-test

Run the hardened image:

    docker run --detach \
      --name image-advanced-test \
      --read-only \
      --tmpfs /tmp \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --memory 128m \
      --cpus 0.50 \
      --publish 3002:3000 \
      container-image-optimization:1.0.0

Validate the application:

    curl http://localhost:3002/
    curl http://localhost:3002/health

Validate the runtime identity:

    docker exec image-advanced-test whoami
    docker exec image-advanced-test id

Validate the health check:

    docker inspect image-advanced-test \
      --format '{{.State.Health.Status}}'

Validate the runtime restrictions:

    docker inspect image-advanced-test \
      --format 'Memory={{.HostConfig.Memory}} NanoCPUs={{.HostConfig.NanoCpus}} ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}}'

Validate resource consumption:

    docker stats image-advanced-test --no-stream

Validate read-only filesystem enforcement:

    docker exec image-advanced-test sh -c 'touch /restricted-file' \
      || echo "Read-only filesystem enforced"

Remove the container:

    docker rm --force image-advanced-test

## Image Analysis

Run the included analysis utility:

    cd ..
    ./analyze-images.sh

The utility reports:

- Image size
- Filesystem layer count
- Configured runtime user
- Differences between baseline and optimized images

Review image history manually:

    docker history container-image-optimization:1.0.0

Inspect image configuration:

    docker image inspect container-image-optimization:1.0.0

Review Docker storage usage:

    docker system df
    docker system df --verbose

## Build-Context Validation

Inspect the optimized image contents:

    docker run --rm \
      container-image-optimization:optimized \
      sh -c 'ls -la /app'

The following development content should not exist inside the optimized image:

- Runtime logs
- Temporary cache files
- Test files
- Development documentation
- Local dependency directories
- Git metadata
- Editor configuration

## Vulnerability Scanning

Run Trivy against the hardened image:

    docker run --rm \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      --volume "$HOME/.cache/trivy:/root/.cache/" \
      aquasec/trivy:latest \
      image \
      --severity HIGH,CRITICAL \
      --ignore-unfixed \
      --no-progress \
      container-image-optimization:1.0.0

Save the report:

    mkdir -p reports

    docker run --rm \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      --volume "$HOME/.cache/trivy:/root/.cache/" \
      aquasec/trivy:latest \
      image \
      --severity HIGH,CRITICAL \
      --ignore-unfixed \
      --no-progress \
      container-image-optimization:1.0.0 \
      | tee reports/trivy-report.txt

A successful build does not imply that an image is vulnerability-free. Scan findings should be reviewed before deployment.

## Safe Cleanup

Review the cleanup utility before execution:

    cat cleanup-images.sh

Run it manually:

    ./cleanup-images.sh

The utility removes stopped containers and older unused build artifacts without performing an unrestricted system-wide deletion.

## Tools Used

- Docker Engine
- Docker CLI
- Docker BuildKit
- Docker Buildx
- Node.js LTS images
- Node.js Alpine images
- npm
- Express
- dumb-init
- Trivy
- curl
- Git
- Linux capability controls
- Docker health checks
- Docker resource limits

## Key Skills Demonstrated

- Container-image lifecycle management
- Semantic image versioning
- Deterministic dependency installation
- Build-context optimization with `.dockerignore`
- Multi-stage Dockerfile construction
- Production dependency isolation
- Non-root runtime execution
- Container-native health checks
- Read-only root filesystem enforcement
- Linux capability reduction
- Privilege-escalation prevention
- CPU and memory restriction
- Vulnerability scanning
- Image size and layer analysis
- Automated but controlled cleanup
- Runtime verification through executable checks

## Real-World Use Case

These practices are used when packaging APIs, microservices, internal platform services, automation components, and machine-learning inference endpoints.

Optimized build contexts and multi-stage images reduce registry storage, transfer time, deployment latency, and unnecessary runtime content. Non-root execution, read-only filesystems, capability reduction, health checks, resource limits, and vulnerability scanning improve security and reliability when images are deployed through Kubernetes, CI/CD pipelines, private registries, or managed container platforms.

## Lessons Learned

- Build contexts should contain only files required to construct the image.
- Lock files make dependency installation more deterministic and auditable.
- Build tools and development dependencies should remain outside final runtime images.
- Multi-stage builds improve runtime efficiency without sacrificing build capability.
- Minimal images reduce unnecessary content but may omit common debugging tools.
- Non-root execution must be designed into the image.
- Health checks should use tools guaranteed to exist in the final runtime.
- Image size is not a complete security measurement.
- Vulnerability scanning is required even when a minimal base image is used.
- Broad pruning commands should not be automated without explicit scope.

## Troubleshooting Log

### Docker Socket Permission Failure

The current user initially lacked Docker socket access.

Resolution:

    sudo usermod -aG docker "$USER"
    newgrp docker

### Registry Publishing Authorization

Registry authentication succeeded, but publishing returned an insufficient-scope authorization error.

Registry publishing was therefore excluded from the final workflow. Local image construction, tagging, optimization, hardening, analysis, and scanning remained fully functional.

### Deprecated npm Production Syntax

The older syntax:

    npm install --only=production

was replaced with:

    npm ci --omit=dev

This provides deterministic installation from the lock file while excluding development dependencies.

### Build-Context Bloat

Logs, temporary files, tests, editor configuration, development documentation, and local dependencies were excluded through `.dockerignore`.

### Read-Only Runtime Requirements

The hardened container uses:

    --read-only
    --tmpfs /tmp

The root filesystem remains immutable while `/tmp` provides controlled temporary writable storage.

### Minimal Runtime Limitations

Minimal images may not contain utilities such as `ps`, `curl`, Bash, or package managers. Validation therefore relies on HTTP endpoints, Docker inspection, health checks, logs, and explicitly available runtime commands.

### Broad Cleanup Risk

Commands such as unrestricted image, volume, or system pruning can remove unrelated resources. Cleanup was implemented as a separate script and was not executed automatically.
