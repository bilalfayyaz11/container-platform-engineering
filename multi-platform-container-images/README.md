# Multi-Platform Container Image Publishing

## What This Does

This implementation builds and publishes a Node.js container image for both AMD64 and ARM64 processor architectures. Docker Buildx coordinates the cross-platform builds, while QEMU emulation enables ARM64 image creation and validation from an AMD64 host.

The published Docker Hub image uses a multi-platform manifest so compatible systems automatically pull the correct architecture variant. This supports x86 cloud servers, ARM-based cloud instances, Apple Silicon development systems, edge platforms, and heterogeneous production infrastructure.

## Architecture

    Application Source
          |
          v
    Multi-Stage Dockerfile
          |
          v
    Docker Buildx Builder
          |
          +-----------------------+
          |                       |
          v                       v
    linux/amd64 Build       linux/arm64 Build
          |                       |
          |                  QEMU Emulation
          |                       |
          +-----------+-----------+
                      |
                      v
             Docker Hub Registry
                      |
                      v
          Multi-Platform Image Manifest
                      |
          +-----------+-----------+
          |                       |
          v                       v
    AMD64 Runtime             ARM64 Runtime
       x64                       arm64

## Prerequisites

- Linux
- Docker Engine
- Docker Buildx
- QEMU user-static support
- binfmt architecture handlers
- Git
- curl
- jq
- Docker Hub account
- Docker Hub access token with Read and Write permission
- At least 4 CPU cores recommended
- At least 4 GB available memory

## Setup & Installation

Verify Docker and Buildx:

```bash
docker --version
docker buildx version
docker info
```

Install QEMU support on Ubuntu:

```bash
sudo apt update
sudo apt install -y qemu-user-static binfmt-support
```

Register AMD64 and ARM64 handlers:

```bash
docker run \
  --privileged \
  --rm \
  tonistiigi/binfmt \
  --install amd64,arm64
```

Create and activate a Buildx builder:

```bash
docker buildx create \
  --name multiarch-builder \
  --driver docker-container \
  --use

docker buildx inspect \
  multiarch-builder \
  --bootstrap
```

Verify supported platforms:

```bash
docker buildx inspect multiarch-builder |
grep Platforms
```

## How to Reproduce

Clone the repository and enter this implementation directory:

```bash
git clone https://github.com/bilalfayyaz11/container-platform-engineering.git
cd container-platform-engineering/multi-platform-container-images
```

Build and load the AMD64 image locally:

```bash
docker buildx build \
  --builder multiarch-builder \
  --platform linux/amd64 \
  --tag multi-platform-runtime-api:amd64 \
  --load \
  .
```

Run and test the AMD64 image:

```bash
docker run -d \
  --name multi-platform-amd64 \
  --platform linux/amd64 \
  --publish 3000:3000 \
  multi-platform-runtime-api:amd64

curl http://127.0.0.1:3000
curl http://127.0.0.1:3000/health
```

Remove the local container:

```bash
docker rm -f multi-platform-amd64
```

Authenticate to Docker Hub securely:

```bash
read -rp "Docker Hub username: " DOCKER_USERNAME
read -rsp "Docker Hub access token: " DOCKER_TOKEN
echo

printf '%s' "$DOCKER_TOKEN" |
docker login \
  --username "$DOCKER_USERNAME" \
  --password-stdin

unset DOCKER_TOKEN
```

Build and publish AMD64 and ARM64 images:

```bash
docker buildx build \
  --builder multiarch-builder \
  --platform linux/amd64,linux/arm64 \
  --tag "${DOCKER_USERNAME}/multi-platform-runtime-api:latest" \
  --tag "${DOCKER_USERNAME}/multi-platform-runtime-api:v1.0.0" \
  --push \
  --provenance=true \
  --sbom=true \
  .
```

Inspect the published manifest:

```bash
docker buildx imagetools inspect \
  "${DOCKER_USERNAME}/multi-platform-runtime-api:latest"
```

Inspect the raw manifest:

```bash
docker buildx imagetools inspect \
  "${DOCKER_USERNAME}/multi-platform-runtime-api:latest" \
  --raw |
jq .
```

Test both architecture variants:

```bash
./test-multiarch.sh
```

Remove the builder when finished:

```bash
docker buildx rm multiarch-builder
```

## Tools Used

- Docker Engine
- Docker Buildx
- BuildKit
- QEMU
- binfmt
- Docker Hub
- Node.js 24
- Express
- Alpine Linux
- Bash
- jq
- Git

## Key Skills Demonstrated

- Multi-platform container image engineering
- AMD64 and ARM64 image generation
- Docker Buildx builder administration
- QEMU-based architecture emulation
- Multi-stage Dockerfile optimization
- Registry authentication using access tokens
- Multi-platform manifest publishing
- Architecture-specific runtime verification
- Build cache inspection and cleanup
- Container health-check implementation
- Software bill of materials generation
- Container provenance generation

## Real-World Use Case

This delivery pattern is useful when the same containerized service must run across x86 cloud servers, ARM-based AWS Graviton instances, Apple Silicon development systems, Kubernetes clusters with mixed worker architectures, and edge computing devices. A single multi-platform image reference removes the need to maintain separate image names and deployment definitions for each CPU architecture.

## Lessons Learned

- A multi-platform build cannot be loaded into the local Docker image store with `--load`; it must be pushed to a registry or exported.
- QEMU and binfmt handlers are required to execute ARM64 build steps on an AMD64 host.
- Docker Buildx uses a dedicated BuildKit container when the `docker-container` driver is selected.
- Multi-platform manifests allow Docker to select the correct image variant automatically.
- Architecture behavior should be validated at runtime rather than relying only on build success.
- Immutable version tags should be published alongside `latest`.
- Provenance and SBOM metadata improve image traceability and supply-chain visibility.

## Troubleshooting Log

### Docker Daemon Access

The current user initially lacked access to the Docker socket.

Resolution:

```bash
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
```

### Broken Default Builder

The default Buildx builder could not communicate with the Docker daemon.

Resolution:

```bash
docker buildx create \
  --name multiarch-builder \
  --driver docker-container \
  --use

docker buildx inspect \
  multiarch-builder \
  --bootstrap
```

### ARM64 Emulation Support

The host did not initially have ARM64 QEMU or binfmt support.

Resolution:

```bash
sudo apt install -y qemu-user-static binfmt-support

docker run \
  --privileged \
  --rm \
  tonistiigi/binfmt \
  --install amd64,arm64
```

### Multi-Platform Load Limitation

This command is invalid for a multi-platform image:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --load \
  .
```

Correct approach:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  .
```

### Architecture Validation

The AMD64 image reported:

```text
x64
```

The ARM64 image reported:

```text
arm64
```

This confirmed that both platform variants were built and executed correctly.
