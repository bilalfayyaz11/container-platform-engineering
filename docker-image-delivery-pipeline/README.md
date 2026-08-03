# Automated Container Delivery Pipeline

## What This Does

This implementation provides an automated CI/CD system for a containerized Node.js API. GitHub Actions validates the source code, runs automated tests, audits dependencies, builds multi-platform Docker images, publishes them to Docker Hub, verifies the published runtime, and performs container security scans.

The delivery workflow produces versioned container images for Linux AMD64 and ARM64 platforms. A separate security workflow scans both repository files and the published image with Trivy and uploads SARIF findings to GitHub Security.

## Architecture

    Developer Push
          |
          v
    GitHub Repository
          |
          +------------------------------+
          |                              |
          v                              v
    Container Delivery              Container Security
          |                              |
          v                              v
    Node.js Tests                  Source Scan
    Dependency Audit              Image Scan
          |                       SARIF Upload
          v
    Docker Buildx
          |
          v
    Multi-Platform Image
    AMD64 + ARM64
          |
          v
    Docker Hub Registry
          |
          v
    Runtime Verification
          |
          v
    Health and API Checks

    Operational Automation
    ├── Staging deployment
    ├── Production deployment
    ├── Container monitoring
    ├── Performance testing
    └── Image rollback

## Prerequisites

- Linux
- Git
- Docker Engine
- Docker Compose
- Node.js 24
- npm
- GitHub CLI
- Docker Hub account
- Docker Hub personal access token
- GitHub repository access
- Apache Bench for performance testing

## Setup & Installation

Load Node.js:

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm use 24
```

Install application dependencies:

```bash
npm ci
```

Run automated tests:

```bash
npm test
```

Build the image locally:

```bash
docker build \
  --tag container-delivery-api:local \
  .
```

Run the local container:

```bash
docker run -d \
  --name container-delivery-api-local \
  --publish 3000:3000 \
  container-delivery-api:local
```

Verify the API:

```bash
curl http://127.0.0.1:3000
curl http://127.0.0.1:3000/health
```

Remove the local container:

```bash
docker rm -f container-delivery-api-local
```

## How to Reproduce

Clone the repository:

```bash
git clone https://github.com/bilalfayyaz11/container-platform-engineering.git
cd container-platform-engineering/docker-image-delivery-pipeline
```

Configure the required GitHub repository secrets:

```text
DOCKER_USERNAME
DOCKER_TOKEN
```

The repository-level GitHub Actions workflows are stored under:

```text
.github/workflows/container-delivery.yml
.github/workflows/container-security.yml
.github/workflows/manual-image-verification.yml
```

Push a change to the main branch:

```bash
git add .
git commit -m "Update automated container delivery"
git push origin main
```

Monitor workflow execution:

```bash
gh run list \
  --repo bilalfayyaz11/container-platform-engineering

gh run watch \
  --repo bilalfayyaz11/container-platform-engineering
```

Run the staging deployment:

```bash
./scripts/deploy-staging.sh \
  DOCKER_HUB_USERNAME \
  latest
```

Run the production deployment on port 8080:

```bash
./scripts/deploy-production.sh \
  DOCKER_HUB_USERNAME \
  latest \
  8080
```

Monitor a deployment:

```bash
./scripts/monitor.sh \
  container-delivery-api-production
```

Run a performance test:

```bash
./scripts/performance-test.sh \
  http://127.0.0.1:3001 \
  500 \
  20
```

Rollback production:

```bash
./scripts/rollback.sh \
  DOCKER_HUB_USERNAME \
  PREVIOUS_IMAGE_TAG \
  8080
```

## Tools Used

- GitHub Actions
- Docker Engine
- Docker Buildx
- Docker Hub
- Node.js 24
- Express
- npm
- Trivy
- GitHub Code Scanning
- SARIF
- GitHub CLI
- Docker Compose
- Bash
- Apache Bench
- Linux
- Git

## Key Skills Demonstrated

- Automated CI/CD pipeline design
- Node.js testing and dependency auditing
- Multi-platform Docker image builds
- Docker Hub registry authentication and publishing
- GitHub Actions workflow orchestration
- Container runtime verification
- Source and container vulnerability scanning
- SARIF security reporting
- Environment-specific deployment automation
- Health-aware container deployment
- Runtime monitoring and log inspection
- Performance testing
- Image-based rollback procedures
- Secure secret management

## Real-World Use Case

This architecture can deliver APIs, internal services, model-serving containers, automation tools, and operational platforms through a repeatable release process. Engineering teams can use the same pattern to validate every change, publish trusted container artifacts, detect vulnerabilities, verify runtime health, deploy across environments, and recover quickly by rolling back to a previously published image.

## Lessons Learned

- GitHub Actions workflows must exist under the repository root `.github/workflows` directory.
- A Docker Hub access token should be used instead of an account password.
- Multi-platform builds require QEMU and Docker Buildx.
- Published images should be started and health-checked before a pipeline is considered successful.
- Container security scanning should validate both source files and final images.
- SARIF results provide centralized security visibility inside GitHub.
- Deployment scripts should fail immediately when a container does not become healthy.
- Rollback operations should reference immutable image tags rather than relying only on `latest`.

## Troubleshooting Log

### GitHub Authentication Persistence

GitHub CLI authentication initially completed in the browser but was not persisted by the installed Snap package.

Resolution:

```bash
sudo snap remove gh
sudo apt install --reinstall -y gh

export GH_CONFIG_DIR="$HOME/.config/gh"

gh auth login \
  --hostname github.com \
  --git-protocol https \
  --web \
  --insecure-storage
```

### Docker Daemon Permission

The current user required Docker group access:

```bash
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
```

### Workflow Discovery Failure

The workflows were initially created inside the implementation directory:

```text
docker-image-delivery-pipeline/.github/workflows
```

GitHub only discovers workflows from:

```text
.github/workflows
```

The workflow files were moved to the repository root and committed again.

### Invalid Trivy Action Version

The security pipeline originally referenced:

```yaml
uses: aquasecurity/trivy-action@0.33.1
```

The missing version prefix caused the jobs to fail during setup.

Corrected reference:

```yaml
uses: aquasecurity/trivy-action@v0.36.0
```

### Headless GitHub Login

The server could not open a graphical browser and displayed:

```text
Error: no DISPLAY environment variable specified
```

The GitHub device authorization process still completed successfully through an external browser.

### Security Scan Cache Warning

The security workflow displayed a non-blocking cache warning:

```text
Cache save failed
```

The source scan, image scan, SARIF upload, and workflow still completed successfully.
