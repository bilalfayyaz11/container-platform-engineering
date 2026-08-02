# Private Registry Security and Operations

## What This Does

This implementation provides a complete local container registry workflow with persistent storage, image versioning, authenticated push and pull operations, registry API inspection, runtime validation, monitoring, troubleshooting, and security checks.

The system builds multiple versions of an Nginx-based web image, stores them in a private OCI-compatible registry, validates immutable image digests, protects the registry with bcrypt-backed credentials, restricts network exposure to the loopback interface, and produces operational reports for maintenance and diagnostics.

The implementation is designed to demonstrate how internal container images can be distributed and managed without depending on a public registry.

## Architecture

    Application Source
           |
           v
    +----------------------+
    | Docker Build         |
    |                      |
    | Version 1.0.0        |
    | Version 2.0.0        |
    | OCI Labels           |
    | Health Checks        |
    +----------+-----------+
               |
               v
    +----------------------+
    | Local Image Store    |
    |                      |
    | Semantic Tags        |
    | Immutable Digests    |
    +----------+-----------+
               |
               v
    +------------------------------+
    | Authenticated Registry       |
    |                              |
    | Distribution Registry 3.x    |
    | htpasswd Authentication      |
    | bcrypt Password Storage      |
    | Persistent Filesystem        |
    | Loopback Network Binding     |
    +---------------+--------------+
                    |
          +---------+----------+
          |                    |
          v                    v
    +------------+      +------------------+
    | Push/Pull  |      | Registry API     |
    | Validation |      |                  |
    |            |      | Catalog          |
    | Runtime    |      | Tags             |
    | Health     |      | Manifests        |
    | Digests    |      | Repository Data  |
    +------------+      +------------------+
                                  |
                                  v
                       +----------------------+
                       | Operations Layer     |
                       |                      |
                       | Monitoring           |
                       | Security Validation  |
                       | Troubleshooting      |
                       | Maintenance Reports  |
                       +----------------------+

## Directory Structure

    private-registry-security-operations/
    ├── README.md
    ├── application/
    │   ├── .dockerignore
    │   ├── Dockerfile
    │   ├── Dockerfile.v2
    │   └── index.html
    ├── registry/
    │   └── config/
    │       └── config.yml
    ├── scripts/
    │   ├── registry-maintenance.sh
    │   ├── registry-monitor.sh
    │   ├── registry-security-check.sh
    │   └── registry-troubleshoot.sh
    └── reports/
        ├── authenticated-catalog.json
        ├── authenticated-tags.json
        ├── authentication-status.txt
        ├── final-authenticated-tags.json
        ├── final-summary.txt
        ├── image-lifecycle-report.txt
        ├── initial-registry-status.txt
        ├── maintenance-report.txt
        ├── monitoring-report.txt
        ├── registry-tags.json
        ├── security-report.txt
        ├── troubleshooting-report.txt
        └── version-2-manifest.json

## Prerequisites

- Ubuntu or another Linux distribution
- Docker Engine
- Docker CLI
- Docker Buildx
- curl
- Python 3
- apache2-utils
- Git
- Available ports `5000`, `8080`, and `8081`

## Environment Verification

Verify the required tools:

    docker --version
    docker compose version
    docker buildx version
    curl --version
    python3 --version
    htpasswd -v
    systemctl is-active docker

Verify Docker access:

    docker info

If Docker socket access is denied:

    sudo usermod -aG docker "$USER"
    newgrp docker

## Application Images

Two application versions are included:

- `registry-web-service:1.0.0`
- `registry-web-service:2.0.0`

Each image contains:

- An Nginx Alpine runtime
- A version-specific web page
- OCI image metadata
- A container-native health check
- A minimal build context controlled by `.dockerignore`

## Build Version 1

    cd application

    docker build \
      --file Dockerfile \
      --tag registry-web-service:1.0.0 \
      --tag registry-web-service:latest \
      .

## Build Version 2

    docker build \
      --file Dockerfile.v2 \
      --tag registry-web-service:2.0.0 \
      .

## Registry Configuration

The registry uses persistent filesystem storage and supports manifest deletion.

The configuration file is located at:

    registry/config/config.yml

The registry stores image data under:

    ~/private-registry-engineering/registry/data

The storage directory is intentionally excluded from Git because registry blobs and uploaded image layers should not be committed to a source repository.

## Start an Unauthenticated Registry

For initial local validation:

    docker run --detach \
      --name private-registry \
      --restart unless-stopped \
      --publish 127.0.0.1:5000:5000 \
      --volume "$HOME/private-registry-engineering/registry/data:/var/lib/registry" \
      --volume "$HOME/private-registry-engineering/registry/config/config.yml:/etc/distribution/config.yml:ro" \
      registry:3

Verify the API:

    curl http://127.0.0.1:5000/v2/

Verify the catalog:

    curl http://127.0.0.1:5000/v2/_catalog |
      python3 -m json.tool

## Tag Images for the Registry

    docker tag \
      registry-web-service:1.0.0 \
      localhost:5000/registry-web-service:1.0.0

    docker tag \
      registry-web-service:1.0.0 \
      localhost:5000/registry-web-service:latest

    docker tag \
      registry-web-service:2.0.0 \
      localhost:5000/registry-web-service:2.0.0

## Push Images

    docker push localhost:5000/registry-web-service:1.0.0
    docker push localhost:5000/registry-web-service:latest
    docker push localhost:5000/registry-web-service:2.0.0

## Inspect Registry Metadata

List repositories:

    curl http://127.0.0.1:5000/v2/_catalog |
      python3 -m json.tool

List image tags:

    curl http://127.0.0.1:5000/v2/registry-web-service/tags/list |
      python3 -m json.tool

Inspect a manifest:

    curl \
      --header 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
      http://127.0.0.1:5000/v2/registry-web-service/manifests/2.0.0 |
      python3 -m json.tool

## Pull Validation

Remove the local registry tags:

    docker image rm \
      localhost:5000/registry-web-service:1.0.0 \
      localhost:5000/registry-web-service:2.0.0 \
      localhost:5000/registry-web-service:latest

Pull the images again:

    docker pull localhost:5000/registry-web-service:1.0.0
    docker pull localhost:5000/registry-web-service:2.0.0

## Runtime Validation

Run version 1:

    docker run --detach \
      --name registry-v1-test \
      --publish 127.0.0.1:8080:80 \
      localhost:5000/registry-web-service:1.0.0

    curl http://127.0.0.1:8080/

    docker inspect registry-v1-test \
      --format '{{.State.Health.Status}}'

    docker rm --force registry-v1-test

Run version 2:

    docker run --detach \
      --name registry-v2-test \
      --publish 127.0.0.1:8081:80 \
      localhost:5000/registry-web-service:2.0.0

    curl http://127.0.0.1:8081/

    docker inspect registry-v2-test \
      --format '{{.State.Health.Status}}'

    docker rm --force registry-v2-test

## Verify Image Digests

    docker image inspect \
      localhost:5000/registry-web-service:1.0.0 \
      --format '{{index .RepoDigests 0}}'

    docker image inspect \
      localhost:5000/registry-web-service:2.0.0 \
      --format '{{index .RepoDigests 0}}'

Distinct digests confirm that each version represents a separate immutable image release.

## Configure Registry Authentication

Create an authentication directory:

    mkdir -p registry/auth

Create a bcrypt-backed user:

    read -rp "Registry username: " REGISTRY_USERNAME
    read -rsp "Registry password: " REGISTRY_PASSWORD
    echo

    htpasswd -Bbn \
      "$REGISTRY_USERNAME" \
      "$REGISTRY_PASSWORD" \
      > registry/auth/htpasswd

    chmod 600 registry/auth/htpasswd

The generated authentication file must never be committed to Git.

## Start the Authenticated Registry

Stop the unauthenticated container:

    docker rm --force private-registry

Start the authenticated registry:

    docker run --detach \
      --name authenticated-registry \
      --restart unless-stopped \
      --publish 127.0.0.1:5000:5000 \
      --volume "$HOME/private-registry-engineering/registry/data:/var/lib/registry" \
      --volume "$HOME/private-registry-engineering/registry/config/config.yml:/etc/distribution/config.yml:ro" \
      --volume "$HOME/private-registry-engineering/registry/auth:/auth:ro" \
      --env REGISTRY_AUTH=htpasswd \
      --env 'REGISTRY_AUTH_HTPASSWD_REALM=Private Registry' \
      --env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
      registry:3

## Verify Anonymous Access Denial

    curl \
      --silent \
      --output /dev/null \
      --write-out '%{http_code}\n' \
      http://127.0.0.1:5000/v2/_catalog

Expected status:

    401

## Authenticate the Docker Client

    docker login localhost:5000

Use the username and password created with `htpasswd`.

Do not place credentials directly in shell history or source-controlled files.

## Verify Authenticated API Access

    curl \
      --user registryuser \
      http://127.0.0.1:5000/v2/_catalog |
      python3 -m json.tool

The password will be requested interactively.

## Operational Scripts

### Registry Monitoring

The monitoring script reports:

- Container status
- Repository count
- Registry catalog
- Persistent storage usage
- Host memory and disk usage
- Container CPU and memory usage
- Recent activity logs

Run it with:

    read -rsp "Registry password: " REGISTRY_PASSWORD
    echo

    REGISTRY_AUTH="registryuser:$REGISTRY_PASSWORD" \
      ./scripts/registry-monitor.sh

    unset REGISTRY_PASSWORD

### Security Validation

The security script verifies:

- htpasswd authentication is enabled
- Anonymous access returns HTTP 401
- Authenticated access returns HTTP 200
- Registry publishing is restricted to loopback
- Authentication file permissions are restricted
- TLS limitations are clearly reported

Run it with:

    read -rsp "Registry password: " REGISTRY_PASSWORD
    echo

    REGISTRY_AUTH="registryuser:$REGISTRY_PASSWORD" \
      ./scripts/registry-security-check.sh

    unset REGISTRY_PASSWORD

### Troubleshooting

The troubleshooting script checks:

- Docker daemon state
- Registry container state
- Registry API connectivity
- Repository catalog access
- Persistent storage capacity
- Recent error logs
- Registry filesystem structure

Run it with:

    read -rsp "Registry password: " REGISTRY_PASSWORD
    echo

    REGISTRY_AUTH="registryuser:$REGISTRY_PASSWORD" \
      ./scripts/registry-troubleshoot.sh

    unset REGISTRY_PASSWORD

### Maintenance Report

The maintenance script displays:

- Current repository catalog
- Available tags
- Storage usage
- Registry-related local images
- Registry container status

It performs no destructive cleanup.

Run it with:

    read -rsp "Registry password: " REGISTRY_PASSWORD
    echo

    REGISTRY_AUTH="registryuser:$REGISTRY_PASSWORD" \
      ./scripts/registry-maintenance.sh

    unset REGISTRY_PASSWORD

## Security Controls

The implementation applies the following controls:

- bcrypt-backed registry credentials
- Anonymous access denial
- Authenticated image push and pull
- Authentication file permissions set to `600`
- Registry port bound to `127.0.0.1`
- Persistent image storage
- Separate credentials from source-controlled content
- Health and API validation
- Explicit reporting of the missing TLS layer

## Production Limitations

This implementation uses HTTP because the registry is bound to the local loopback interface for isolated validation.

A production deployment must also include:

- TLS certificates
- A trusted hostname
- A stable shared HTTP secret
- External identity and access management
- Authorization policies
- Credential rotation
- Audit logging
- Backup and restore procedures
- High availability
- Registry garbage collection planning
- Image signing and provenance verification
- Vulnerability scanning
- Network segmentation

## HTTP Secret Warning

Distribution Registry may generate a random HTTP secret when none is provided.

For a single registry container, this warning does not prevent normal push and pull operations. Multiple registry replicas behind a load balancer must share the same configured HTTP secret.

A production configuration should define:

    http:
      secret: replace-with-a-secure-shared-value

The real secret must be supplied through a protected secret-management system rather than committed to Git.

## Tools Used

- Docker Engine
- Docker CLI
- Docker Buildx
- Distribution Registry 3.x
- Nginx Alpine
- htpasswd
- bcrypt
- curl
- Python 3
- Bash
- Git
- Linux filesystem permissions
- OCI image metadata
- Registry HTTP API V2

## Skills Demonstrated

- Private container registry deployment
- Persistent registry storage
- Semantic image versioning
- Image push and pull workflows
- Immutable image digest verification
- Registry API inspection
- OCI manifest inspection
- Registry authentication
- bcrypt credential storage
- Anonymous access prevention
- Local network exposure restriction
- Container runtime health validation
- Registry monitoring
- Operational troubleshooting
- Security control verification
- Non-destructive maintenance reporting
- Container distribution architecture

## Real-World Use Case

Private registries are used to distribute internal APIs, automation services, microservices, platform components, and machine-learning inference images.

They allow organizations to control image access, retain proprietary artifacts, manage versioned releases, reduce dependence on public infrastructure, support isolated environments, and integrate trusted image sources into CI/CD and Kubernetes deployment workflows.

## Lessons Learned

- Image tags are convenient references, but digests provide immutable identity.
- Pull-back testing proves that an image exists independently in registry storage.
- Registry data must be stored outside the registry container.
- Registry credentials must never be committed to source control.
- Authentication without TLS is insufficient for remote production traffic.
- Binding local infrastructure to loopback reduces unnecessary exposure.
- API inspection provides direct visibility into repositories, tags, and manifests.
- Monitoring must include both registry state and host resource usage.
- Troubleshooting scripts should collect evidence without changing system state.
- Cleanup and garbage collection require explicit operational policies.

## Troubleshooting Log

### Docker Socket Permission Failure

The initial user did not have permission to access the Docker socket.

Resolution:

    sudo usermod -aG docker "$USER"
    newgrp docker

### Missing htpasswd Utility

The authentication utility was not initially installed.

Resolution:

    sudo apt-get update
    sudo apt-get install -y apache2-utils

### Registry Container Name Mismatch

An unauthenticated container remained active under the name:

    private-registry

The authenticated registry was expected under:

    authenticated-registry

The existing container was removed and the authenticated instance was recreated with the same persistent storage.

### Anonymous Access Verification

The authenticated registry correctly returned:

    HTTP 401

This confirmed that anonymous catalog access was blocked.

### Pipeline Exit During Storage Listing

A command using:

    find ... | head

was executed with `set -o pipefail`.

After `head` exited, `find` received a broken pipe and caused the script to stop. The command was replaced with:

    find ... | sed -n '1,15p'

### Registry HTTP Secret Warning

The registry reported that no shared HTTP secret was configured.

This was acceptable for a single local instance, but production replicas must share a stable secret.

### Public Registry Publishing

Public registry publishing was intentionally excluded. The implementation focuses on local private image distribution, authentication, API inspection, persistent storage, and operational controls.
