# BuildKit Cache and Image Optimization

## What This Does

This implementation demonstrates a production-oriented container build workflow using Docker BuildKit and Buildx.

It compares conventional container builds with dependency-aware multi-stage builds, package-manager cache mounts, external cache export and import, secure build-time secrets, parallel build stages, metadata generation, and Docker Compose integration.

The workflow includes Node.js and Go services so that BuildKit behavior can be evaluated across interpreted and compiled applications.

The final implementation produces optimized non-root runtime images, measurable build-performance evidence, secret-leak validation, portable build caches, detailed build metadata, and safe cleanup automation.

## Architecture

    Source Code
        |
        +--------------------------+
        |                          |
        v                          v
    Node.js Service            Go Service
        |                          |
        v                          v
    Dependency Stage          Module Stage
        |                          |
        | npm Cache Mount          | Go Module Cache
        |                          | Compiler Cache
        v                          v
    Validation Stage          Test Stage
        |                          |
        v                          v
    Runtime Assembly          Binary Compilation
        |                          |
        v                          v
    Non-Root Node Image       Scratch Runtime Image
        |                          |
        +------------+-------------+
                     |
                     v
          Docker BuildKit / Buildx
                     |
        +------------+-------------+
        |            |             |
        v            v             v
    Local Cache   Metadata     Plain Build Logs
    Export/Import Generation   and Diagnostics
        |
        v
    Separate Buildx Builder
    Cache Reuse Validation

## Directory Structure

    buildkit-cache-and-image-optimization/
    ├── README.md
    ├── compose.yaml
    ├── node-service/
    │   ├── .dockerignore
    │   ├── Dockerfile
    │   ├── Dockerfile.parallel
    │   ├── Dockerfile.secret
    │   ├── Dockerfile.traditional
    │   ├── package.json
    │   ├── package-lock.json
    │   ├── server.js
    │   └── test.js
    ├── go-service/
    │   ├── .dockerignore
    │   ├── Dockerfile
    │   ├── Dockerfile.single-stage
    │   ├── go.mod
    │   ├── main.go
    │   └── main_test.go
    ├── scripts/
    │   ├── cleanup-build-resources.sh
    │   ├── measure-go-builds.sh
    │   └── measure-node-builds.sh
    ├── metrics/
    │   ├── advanced-build-times.csv
    │   ├── go-build-times.csv
    │   └── node-build-times.csv
    └── reports/
        ├── advanced-buildkit-summary.txt
        ├── build-secret-validation.txt
        ├── buildkit-cached.log
        ├── buildkit-debug-output.log
        ├── buildx-builder-inspection.txt
        ├── compose-build.log
        ├── final-buildkit-report.txt
        ├── final-image-inventory.csv
        ├── final-performance-summary.txt
        ├── go-build-summary.txt
        ├── go-image-comparison.txt
        ├── node-build-metadata.json
        ├── node-build-summary.txt
        ├── node-cache-import.log
        ├── node-image-comparison.txt
        ├── parallel-build.log
        ├── secret-image-history.txt
        └── secret-runtime-environment.txt

## Prerequisites

- Linux operating system
- Docker Engine
- Docker CLI
- Docker Buildx
- Docker Compose
- Git
- curl
- jq
- Python 3
- Bash
- Standard Linux process and networking utilities
- Available host ports `3000`, `3001`, `3002`, `8080`, `8081`, and `8082`

Host installations of Node.js and Go are not required because dependency installation, testing, and compilation occur inside container build stages.

## Environment Verification

Verify Docker and Buildx:

    docker --version
    docker compose version
    docker buildx version
    docker info
    docker buildx ls

Verify the dedicated builders:

    docker buildx inspect engineering-builder
    docker buildx inspect cache-validation-builder

Verify host utilities:

    curl --version
    jq --version
    python3 --version
    git --version

## Dedicated Buildx Builder

The workflow uses a Docker-container Buildx builder:

    docker buildx create \
      --name engineering-builder \
      --driver docker-container \
      --use

Bootstrap the builder:

    docker buildx inspect \
      engineering-builder \
      --bootstrap

A second isolated builder validates that exported caches can be reused outside the original builder:

    docker buildx create \
      --name cache-validation-builder \
      --driver docker-container

    docker buildx inspect \
      cache-validation-builder \
      --bootstrap

## Why a Docker-Container Builder Is Used

The Docker-container Buildx driver provides advanced BuildKit capabilities such as:

- local cache export
- local cache import
- detailed metadata generation
- isolated builder storage
- portable cache validation
- builder-specific disk usage
- reproducible BuildKit execution

## Node.js Service

The Node.js service provides:

- health endpoint
- application endpoint
- deterministic dependency lock file
- automated test
- non-root runtime
- container health check

Run the application test during the build:

    npm test

The final runtime image uses:

    USER node

## Traditional Node.js Build

The comparison image installs dependencies and runs the service in one stage.

Build it:

    cd node-service

    docker build \
      --file Dockerfile.traditional \
      --tag node-build:traditional \
      .

This image is useful as a baseline for comparing layer structure, build performance, and runtime configuration.

## Optimized Node.js Multi-Stage Build

The optimized Dockerfile separates:

- dependency installation
- application validation
- runtime assembly

Build it:

    cd node-service

    docker buildx build \
      --builder engineering-builder \
      --load \
      --progress plain \
      --file Dockerfile \
      --tag node-build:optimized \
      .

The dependency stage uses:

    RUN --mount=type=cache,id=node-npm-cache,target=/root/.npm,sharing=locked \
        npm ci --omit=dev

This cache mount persists npm download artifacts without copying the cache into the final image.

## Dependency-Aware Layer Ordering

The package manifests are copied before application source:

    COPY package.json package-lock.json ./

    RUN npm ci --omit=dev

    COPY server.js ./

This prevents application source changes from invalidating the dependency installation layer.

## Node.js Cache Measurement

The measurement script is located at:

    scripts/measure-node-builds.sh

Run it:

    ./scripts/measure-node-builds.sh

It records:

- traditional cold build
- BuildKit cold build
- BuildKit cached rebuild
- rebuild after application source change

Results are saved in:

    metrics/node-build-times.csv

Expected structure:

    build,elapsed_ms
    traditional-cold,...
    buildkit-cold,...
    buildkit-cached,...
    buildkit-source-change,...

## BuildKit Cache Evidence

Inspect cached build logs:

    grep -E 'CACHED|cache hit' \
      reports/buildkit-cached.log

Inspect source-change cache behavior:

    grep -E 'CACHED|COPY server.js|COPY package.json|npm ci' \
      reports/buildkit-source-change.log

A source-only change should rebuild source-dependent stages while preserving dependency stages.

## Secure Build Secrets

The secret-aware Dockerfile uses:

    RUN --mount=type=secret,id=private_build_token,required=true \
        TOKEN="$(cat /run/secrets/private_build_token)" && \
        test -n "$TOKEN"

Build with a temporary secret:

    docker buildx build \
      --builder engineering-builder \
      --load \
      --secret id=private_build_token,src=/path/to/secret-file \
      --file node-service/Dockerfile.secret \
      --tag node-build:secret-safe \
      node-service

The secret is mounted only for the relevant build instruction.

It is not passed through:

- `ARG`
- `ENV`
- source files
- image labels
- runtime configuration

## Secret-Leak Validation

The workflow checks the secret against:

- build logs
- image history
- image configuration
- final root filesystem
- runtime environment
- runtime secret mount path

Inspect image history:

    docker history \
      --no-trunc \
      node-build:secret-safe

Inspect image configuration:

    docker image inspect \
      node-build:secret-safe

Inspect runtime environment:

    docker run --rm \
      node-build:secret-safe \
      env

Verify the secret mount does not exist at runtime:

    docker run --rm \
      --entrypoint sh \
      node-build:secret-safe \
      -c 'test ! -e /run/secrets/private_build_token'

## Parallel Build Stages

The parallel Dockerfile defines independent stages for:

- production dependencies
- validation dependencies
- application tests
- JavaScript syntax validation

Build it:

    docker buildx build \
      --builder engineering-builder \
      --load \
      --progress plain \
      --file node-service/Dockerfile.parallel \
      --tag node-build:parallel \
      node-service

BuildKit evaluates the dependency graph and can execute independent stages concurrently.

Inspect the evidence:

    grep -E \
      'production-dependencies|validation-dependencies|test|source-validation|CACHED|DONE' \
      reports/parallel-build.log

## Go Service

The Go service provides:

- JSON health endpoint
- automated handler test
- statically compiled Linux binary
- non-root scratch runtime
- compiler and module cache mounts

## Single-Stage Go Build

The comparison image includes:

- Go compiler
- source code
- module cache
- build tooling
- runtime binary

Build it:

    cd go-service

    docker build \
      --file Dockerfile.single-stage \
      --tag go-build:single-stage \
      .

This image establishes the baseline for size comparison.

## Optimized Go Multi-Stage Build

The optimized build separates:

- module dependency handling
- test execution
- binary compilation
- final runtime

Build it:

    cd go-service

    docker buildx build \
      --builder engineering-builder \
      --load \
      --progress plain \
      --file Dockerfile \
      --tag go-build:optimized \
      .

The module cache uses:

    RUN --mount=type=cache,id=go-module-cache,target=/go/pkg/mod,sharing=locked \
        go mod download

The compiler cache uses:

    RUN --mount=type=cache,id=go-build-cache,target=/root/.cache/go-build,sharing=locked \
        go test ./...

## Static Go Binary

The binary is compiled with:

    CGO_ENABLED=0
    GOOS=linux
    GOARCH=amd64

Build flags:

    go build \
      -trimpath \
      -ldflags="-s -w" \
      -o /out/service \
      .

These options:

- remove local source paths
- reduce binary size
- remove symbol and debug tables
- make the binary compatible with a scratch runtime

## Scratch Runtime Image

The final Go runtime uses:

    FROM scratch

Only the compiled binary is copied:

    COPY --from=builder /out/service /service

The configured runtime user is:

    USER 65532:65532

This excludes the compiler, shell, package manager, source code, and build cache from the production image.

## Go Build Measurements

The measurement script is located at:

    scripts/measure-go-builds.sh

Run it:

    ./scripts/measure-go-builds.sh

It records:

- single-stage build
- multi-stage cold build
- multi-stage cached build
- rebuild after source change

Results are saved in:

    metrics/go-build-times.csv

## Image Size Comparison

Inspect image sizes:

    docker image inspect \
      go-build:single-stage \
      go-build:optimized \
      --format '{{index .RepoTags 0}} size_bytes={{.Size}} user={{.Config.User}}'

The scratch-based image should be significantly smaller than the single-stage compiler image.

## Runtime Filesystem Validation

Export the final image filesystem:

    docker create \
      --name go-rootfs-check \
      go-build:optimized

    docker export go-rootfs-check \
      > go-rootfs.tar

    tar -tf go-rootfs.tar

The runtime image should not contain:

- Go compiler
- Go module cache
- source files
- package manager
- shell
- test files

## Docker Compose Integration

The Compose configuration builds and runs both services.

Validate it:

    docker compose \
      --file compose.yaml \
      config

Build both images:

    docker compose \
      --file compose.yaml \
      build \
      --progress plain

Start the services:

    docker compose \
      --file compose.yaml \
      up \
      --detach

Inspect status:

    docker compose \
      --file compose.yaml \
      ps

Test the Node.js service:

    curl http://127.0.0.1:3002/health

Test the Go service:

    curl http://127.0.0.1:8082/health

Stop the services:

    docker compose \
      --file compose.yaml \
      down

## External Cache Export

Export the Node.js cache:

    docker buildx build \
      --builder engineering-builder \
      --progress plain \
      --cache-to type=local,dest=cache/node-local-cache,mode=max \
      --file node-service/Dockerfile \
      --tag node-build:cache-export \
      node-service

A valid cache directory contains:

    cache/node-local-cache/index.json

Export the Go cache:

    docker buildx build \
      --builder engineering-builder \
      --progress plain \
      --cache-to type=local,dest=cache/go-local-cache,mode=max \
      --file go-service/Dockerfile \
      --tag go-build:cache-export \
      go-service

## External Cache Import

Import the cache using an independent builder:

    docker buildx build \
      --builder cache-validation-builder \
      --load \
      --progress plain \
      --cache-from type=local,src=cache/node-local-cache \
      --file node-service/Dockerfile \
      --tag node-build:cache-import \
      node-service

This proves that the cache is portable and not limited to the original builder instance.

Inspect cache-import evidence:

    grep -E \
      'importing cache manifest|CACHED|cache' \
      reports/node-cache-import.log

## Build Metadata

Generate metadata:

    docker buildx build \
      --builder engineering-builder \
      --load \
      --metadata-file reports/node-build-metadata.json \
      --progress plain \
      --file node-service/Dockerfile \
      --tag node-build:metadata \
      node-service

Inspect it:

    python3 -m json.tool \
      reports/node-build-metadata.json

List metadata keys:

    jq 'keys' \
      reports/node-build-metadata.json

Metadata can include:

- image digest
- configuration digest
- provenance information
- descriptor information
- build references

## Plain Build Progress

Capture detailed BuildKit output:

    BUILDKIT_PROGRESS=plain \
    docker buildx build \
      --builder engineering-builder \
      --load \
      --progress plain \
      --file node-service/Dockerfile \
      --tag node-build:debug-output \
      node-service

Plain output is useful for CI systems because it produces line-oriented build evidence instead of an interactive terminal display.

## Builder Disk Usage

Inspect BuildKit storage:

    docker buildx du \
      --builder engineering-builder

Inspect the cache-validation builder:

    docker buildx du \
      --builder cache-validation-builder

Inspect Docker-wide storage:

    docker system df

## Runtime Validation

Run the optimized Node.js service:

    docker run -d \
      --name node-build-service \
      --publish 127.0.0.1:3000:3000 \
      node-build:optimized

Test it:

    curl http://127.0.0.1:3000/health

Verify its runtime user:

    docker exec node-build-service id

Run the optimized Go service:

    docker run -d \
      --name go-build-service \
      --publish 127.0.0.1:8080:8080 \
      go-build:optimized

Test it:

    curl http://127.0.0.1:8080/health

Verify the configured user:

    docker inspect go-build-service \
      --format '{{.Config.User}}'

## Performance Reports

Node.js timings:

    cat metrics/node-build-times.csv

Go timings:

    cat metrics/go-build-times.csv

Consolidated summary:

    cat reports/final-performance-summary.txt

Image inventory:

    cat reports/final-image-inventory.csv

## Security Characteristics

The final implementation demonstrates:

- non-root Node.js runtime
- non-root Go runtime
- scratch-based Go image
- no build secret stored in image layers
- no build secret in image history
- no build secret in runtime environment
- no package-manager cache copied into final images
- no compiler copied into the Go runtime
- deterministic dependency installation
- scoped resource cleanup

## Reproducibility

The Node.js service uses:

    package-lock.json
    npm ci

This ensures dependency installation follows the committed lock file.

The Go service uses:

    go.mod

Build inputs are separated from output artifacts, and all application compilation occurs inside controlled container stages.

## BuildKit Features Demonstrated

- Docker-container Buildx driver
- build graph execution
- layer cache reuse
- cache mounts
- cache sharing modes
- secret mounts
- multi-stage builds
- parallel stages
- external cache export
- external cache import
- metadata generation
- plain build progress
- builder storage inspection
- Compose build integration
- source-layer invalidation testing
- minimal runtime image creation

## Tools Used

- Docker Engine
- Docker CLI
- Docker Buildx
- Docker BuildKit
- Docker Compose
- Node.js
- npm
- Express
- Lodash
- Go
- Alpine Linux
- scratch container image
- curl
- jq
- Python
- Bash
- Git

## Skills Demonstrated

- Container build optimization
- Build graph design
- Dependency-aware Dockerfile ordering
- Package-manager caching
- Compiler caching
- Multi-stage image construction
- Minimal runtime image creation
- Non-root container execution
- Secure build-time secret handling
- Cache export and import
- CI-compatible build logging
- Build metadata inspection
- Image size analysis
- Build performance benchmarking
- Docker Compose build orchestration
- Builder storage management
- Reproducible dependency installation
- Safe Docker resource cleanup

## Real-World Use Case

These techniques apply to software delivery pipelines where images are built frequently across developer machines, CI runners, release systems, and deployment environments.

Without cache-aware builds, every source change can trigger unnecessary dependency downloads and compilation. Without multi-stage builds, production images may contain compilers, package managers, source code, and test dependencies.

This implementation demonstrates how to:

- accelerate repeated builds
- isolate build dependencies
- reduce production image size
- prevent build-secret leakage
- transport caches between builders
- generate machine-readable build metadata
- produce repeatable evidence for build analysis

## Lessons Learned

- BuildKit is the standard modern Docker build engine.
- A Docker-container Buildx driver unlocks advanced cache exporters.
- Cache mounts improve repeated package-manager operations.
- Layer ordering determines whether source changes invalidate dependency installation.
- Lock files are required for deterministic `npm ci` builds.
- `npm ci --omit=dev` is preferred for production dependency installation.
- Build secrets should use secret mounts rather than build arguments.
- Secret mounts are temporary and do not automatically persist into the final image.
- Multi-stage builds separate compilation from runtime delivery.
- Scratch images can dramatically reduce compiled application image size.
- Static binaries simplify minimal runtime construction.
- Independent stages can execute concurrently through the BuildKit dependency graph.
- External caches can be reused by separate builders.
- Build metadata provides machine-readable evidence for CI and supply-chain systems.
- Plain build output is easier to retain and analyze in automation.
- Cleanup commands should target only explicitly created resources.

## Troubleshooting Log

### Docker Socket Permission

The initial user could not access the Docker daemon.

Resolution:

    sudo usermod -aG docker "$USER"
    newgrp docker

The active workflow used:

    sg docker -c 'bash -s'

to apply Docker group access without ending the session.

### Default Buildx Builder Error

The initial default builder could not connect because Docker socket access was denied.

Resolution:

- correct Docker group membership
- create a dedicated Docker-container builder
- bootstrap the builder before use

### Node.js and Go Missing on Host

Node.js, npm, and Go were not installed on the host.

No host installation was required because:

- Node package-lock generation ran in a Node container
- npm installation ran in build stages
- Go testing and compilation ran in Go build stages

### BuildKit Cache Verification

Cached builds were confirmed through plain BuildKit logs containing:

    CACHED

A source-only modification preserved the dependency installation stages.

### Secret Handling

A temporary build token was mounted using:

    --mount=type=secret

The token was checked against:

- build logs
- image history
- image configuration
- exported root filesystem
- runtime environment

The temporary secret file was securely removed after testing.

### Go Runtime Size

The single-stage image included the Go toolchain.

The optimized image used:

    FROM scratch

and copied only the compiled binary.

### External Cache Portability

The Node.js cache was exported by `engineering-builder` and imported by `cache-validation-builder`.

This confirmed that the cache could be reused by a separate BuildKit instance.

### Compose Syntax

The Compose file does not include the obsolete top-level `version:` field.

The modern command is:

    docker compose

rather than:

    docker-compose

### Safe Cleanup

The cleanup script removes only:

- containers with the implementation label
- Node and Go images created by this workflow
- dedicated Buildx builders
- the dedicated Docker network
- Compose resources from this implementation

It does not remove unrelated containers, images, volumes, networks, or caches.

## Safe Cleanup

Validate the script:

    bash -n scripts/cleanup-build-resources.sh

Run it:

    ./scripts/cleanup-build-resources.sh

The script targets resources created by this implementation rather than using destructive host-wide commands.
