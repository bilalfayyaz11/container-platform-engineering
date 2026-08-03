# Container Security Engineering Baseline

## Overview

This implementation secures Docker across the daemon, image, runtime, and automated scanning layers.

It applies namespace isolation, restricted container communication, no-new-privileges enforcement, seccomp controls, resource limits, non-root execution, minimal image construction, vulnerability scanning, secret detection, and Dockerfile auditing.

## Architecture

    Docker Host
        |
        +-- Hardened Docker Daemon
        |     +-- User namespace remapping
        |     +-- Inter-container communication disabled
        |     +-- No-new-privileges enabled
        |     +-- Custom seccomp profile
        |     +-- Log rotation
        |     +-- File descriptor limits
        |
        +-- Hardened Container
        |     +-- Ubuntu build stage
        |     +-- Alpine runtime
        |     +-- Non-root UID 1001
        |     +-- Read-only filesystem
        |     +-- Capabilities dropped
        |     +-- Memory and PID limits
        |
        +-- Security Pipeline
              +-- Trivy CVE scan
              +-- Trivy secret scan
              +-- Trivy misconfiguration scan
              +-- Dockle assessment
              +-- Hadolint audit
              +-- Structured reports

## Directory Structure

    container-security-engineering/
    ├── daemon-hardening/
    ├── secure-app/
    ├── vulnerable-app/
    ├── reports/
    ├── runtime-validation/
    ├── pipeline-validation/
    ├── tool-verification/
    ├── scan-pipeline.sh
    ├── dockerfile-audit.txt
    └── README.md

## Prerequisites

- Ubuntu Linux
- Docker Engine
- Trivy
- Hadolint
- Dockle
- Bash
- jq
- curl
- Git

## Build the Secure Image

    docker build --tag secure-app:1.0 secure-app

Verify the runtime user and image size:

    docker image inspect secure-app:1.0       --format 'User={{.Config.User}} Size={{.Size}}'

## Run the Hardened Container

    docker run -d       --name secure-app-runtime       --read-only       --tmpfs /tmp:rw,noexec,nosuid,size=8m       --cap-drop ALL       --memory 64m       --pids-limit 50       --security-opt no-new-privileges:true       --publish 8080:8080       secure-app:1.0

Validate the runtime:

    docker inspect secure-app-runtime       --format '{{.State.Health.Status}}'

    curl http://127.0.0.1:8080

    docker exec secure-app-runtime id

    docker stats secure-app-runtime --no-stream

## Run the Security Pipeline

Scan the hardened image:

    bash scan-pipeline.sh secure-app:1.0

Scan the deliberately vulnerable image:

    bash scan-pipeline.sh vulnerable-app:latest

Expected behavior:

    secure-app:1.0          exit code 0
    vulnerable-app:latest  exit code 1

## Pipeline Coverage

The automated workflow performs:

- HIGH and CRITICAL CVE detection
- Embedded secret detection
- Image misconfiguration detection
- Dockle security assessment
- Dockerfile linting
- Structured JSON report generation
- Exit-code-based security gating

Reports are stored in:

    reports/

## Dockerfile Audit

Run Hadolint:

    hadolint --failure-threshold error secure-app/Dockerfile
    hadolint --failure-threshold error vulnerable-app/Dockerfile

Consolidated findings are stored in:

    dockerfile-audit.txt

## Security Controls

### Daemon

- User namespace remapping
- Inter-container communication disabled
- No-new-privileges enabled
- Custom seccomp profile
- JSON log rotation
- Default nofile limit of 64000

### Image

- Multi-stage construction
- Minimal Alpine runtime
- Non-root UID 1001
- Health check
- No build tools in the final image

### Runtime

- Read-only root filesystem
- Temporary writable `/tmp`
- All Linux capabilities dropped
- 64 MB memory limit
- PID limit of 50
- Host UID remapping

### Pipeline

- CVE security gate
- Secret scanning
- Misconfiguration scanning
- Dockerfile policy checks
- Structured audit evidence

## Results

    Docker daemon: hardened
    User namespace remapping: enabled
    Inter-container communication: blocked
    Secure image user: 1001:1001
    Secure image size: below 20 MB
    Container health: healthy
    HTTP response: 200
    Read-only filesystem: enabled
    Capabilities: all dropped
    Memory limit: 64 MB
    PID limit: 50
    Vulnerable image exit code: 1
    Secure image exit code: 0
    Reports generated per image: 4
    Hadolint ERROR findings: 0

## Tools Used

- Docker Engine
- Trivy
- Hadolint
- Dockle
- AppArmor
- Seccomp
- Linux user namespaces
- Alpine Linux
- Ubuntu
- Bash
- jq
- curl

## Skills Demonstrated

- Docker daemon hardening
- Container runtime isolation
- Minimal image construction
- Non-root execution
- Capability reduction
- Resource governance
- Vulnerability scanning
- Secret detection
- Dockerfile policy enforcement
- Automated security gating
- Structured audit reporting

## Troubleshooting

The initial runtime failed because the default BusyBox package did not provide the `httpd` command.

Resolution:

    RUN apk add --no-cache busybox-extras

The startup script was initially not writable because it used mode `0555`.

Resolution:

    chmod u+rw secure-app/start.sh

Docker process inspection requires the PID field:

    docker top secure-app-runtime       -eo pid,user,uid,gid,comm,args

## Real-World Use Case

This implementation provides a reusable security baseline for Kubernetes platforms, DevSecOps pipelines, AI service packaging, cloud workloads, internal developer platforms, and regulated environments.

The vulnerable image proves that unsafe artifacts are rejected while the hardened image passes the security gate.

## Cleanup

    docker rm -f secure-app-runtime
    docker image rm secure-app:1.0
    docker image rm vulnerable-app:latest
    docker builder prune -f
