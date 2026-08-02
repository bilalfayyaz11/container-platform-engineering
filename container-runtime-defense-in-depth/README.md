# Container Runtime Defense in Depth

## What This Does

This implementation hardens a containerized Python service using multiple independent Linux and Docker security controls.

It combines daemon-level user namespace remapping, a non-root application identity, custom seccomp filtering, AppArmor mandatory access control, dropped Linux capabilities, no-new-privileges enforcement, a read-only root filesystem, controlled temporary storage, vulnerability scanning, and cgroup-based resource limits.

The workflow also includes executable validation scripts and reports that prove each security control is active rather than relying only on static configuration.

## Architecture

    Application Source
           |
           v
    +----------------------------+
    | Hardened Container Image   |
    |                            |
    | Python Alpine Runtime      |
    | UID/GID 10001              |
    | Health Check               |
    | Minimal Build Context      |
    +-------------+--------------+
                  |
                  v
    +--------------------------------------+
    | Docker Runtime Security              |
    |                                      |
    | User Namespace Remapping             |
    | Non-Root Execution                   |
    | Custom Seccomp Profile               |
    | AppArmor Policy                      |
    | No-New-Privileges                    |
    | All Capabilities Dropped             |
    | Read-Only Root Filesystem            |
    | Restricted tmpfs                     |
    +------------------+-------------------+
                       |
                       v
    +--------------------------------------+
    | Resource Governance                  |
    |                                      |
    | Memory Limit                         |
    | CPU Quota                            |
    | PID Limit                            |
    | File Descriptor Limit                |
    | cgroup v2 Enforcement                |
    +------------------+-------------------+
                       |
                       v
    +--------------------------------------+
    | Security Verification                |
    |                                      |
    | Runtime Identity Checks              |
    | Syscall Blocking Tests               |
    | AppArmor Denial Tests                |
    | Vulnerability Scans                  |
    | Filesystem Boundary Tests            |
    | Resource Inspection                  |
    | Reusable Secure Launcher             |
    +--------------------------------------+

## Directory Structure

    container-runtime-defense-in-depth/
    ├── README.md
    ├── images/
    │   ├── .dockerignore
    │   ├── Dockerfile.hardened
    │   ├── Dockerfile.nonroot
    │   ├── Dockerfile.outdated
    │   └── server.py
    ├── seccomp/
    │   └── runtime-restricted.json
    ├── apparmor/
    │   └── container-security-runtime
    ├── scripts/
    │   └── secure-container-launcher.sh
    └── reports/
        ├── application-image-scan.txt
        ├── apparmor-basic-test.txt
        ├── apparmor-denial-test.txt
        ├── apparmor-mount-test.txt
        ├── cgroup-resource-limits.txt
        ├── combined-security-report.txt
        ├── defense-in-depth-response.json
        ├── docker-security-options.json
        ├── final-launcher-test.txt
        ├── final-process-security.txt
        ├── final-resource-limits.txt
        ├── final-runtime-response.json
        ├── final-security-report.txt
        ├── hardened-image-scan.txt
        ├── host-ownership-mapping.txt
        ├── nonroot-runtime-response.json
        ├── outdated-image-scan.txt
        ├── resource-security-report.txt
        ├── resource-usage.txt
        ├── seccomp-basic-test.txt
        ├── seccomp-block-test.txt
        ├── secure-launcher-validation.txt
        ├── user-namespace-mapping.txt
        ├── user-namespace-nonroot-report.txt
        └── vulnerability-summary.txt

## Prerequisites

- Ubuntu or another Linux distribution with AppArmor support
- Docker Engine
- Docker Buildx
- containerd
- cgroup v2
- Python 3
- curl
- jq
- AppArmor utilities
- Git
- At least 2 GB of available disk space

## Environment Verification

Verify Docker and host security features:

    docker --version
    docker buildx version
    containerd --version
    systemctl is-active docker
    sudo aa-status
    stat -fc %T /sys/fs/cgroup

Inspect Docker security options:

    docker info --format '{{json .SecurityOptions}}' |
      python3 -m json.tool

Expected Docker security capabilities include:

    name=apparmor
    name=seccomp,profile=builtin
    name=cgroupns
    name=userns

## Docker Access

Add the current user to the Docker group when required:

    sudo usermod -aG docker "$USER"
    newgrp docker

Verify access:

    docker info

## User Namespace Remapping

The Docker daemon is configured with:

    {
      "userns-remap": "default"
    }

This creates the `dockremap` identity and subordinate UID/GID mappings.

Verify the remapping account:

    getent passwd dockremap
    grep '^dockremap:' /etc/subuid
    grep '^dockremap:' /etc/subgid

Verify Docker’s storage location and security options:

    docker info --format '{{.DockerRootDir}}'
    docker info --format '{{json .SecurityOptions}}'

### Host Ownership Translation

Container root should not map to host root.

Create a test directory:

    mkdir -p /tmp/userns-validation
    chmod 777 /tmp/userns-validation

Create a file as container root:

    docker run --rm \
      --volume /tmp/userns-validation:/mapping \
      alpine:latest \
      touch /mapping/container-root-file

Inspect host ownership:

    ls -ln /tmp/userns-validation/container-root-file

The host UID should be a subordinate remapped UID rather than UID `0`.

## Build the Non-Root Application Image

    cd images

    docker build \
      --file Dockerfile.nonroot \
      --tag container-security-runtime:1.0.0 \
      .

Inspect the configured identity:

    docker image inspect \
      container-security-runtime:1.0.0 \
      --format 'User={{.Config.User}} Size={{.Size}}'

Expected user:

    10001:10001

## Run the Hardened Application

    docker run --detach \
      --name container-security-runtime \
      --publish 127.0.0.1:8080:8080 \
      --security-opt no-new-privileges:true \
      --user 10001:10001 \
      --cap-drop ALL \
      --read-only \
      --tmpfs /tmp:rw,noexec,nosuid,size=32m \
      --memory 128m \
      --memory-swap 128m \
      --cpus 0.50 \
      --pids-limit 64 \
      --ulimit nofile=1024:1024 \
      container-security-runtime:1.0.0

Validate the service:

    curl http://127.0.0.1:8080/

Validate health:

    docker inspect container-security-runtime \
      --format '{{.State.Health.Status}}'

Validate identity:

    docker exec container-security-runtime id

Remove the container:

    docker rm --force container-security-runtime

## Custom Seccomp Profile

The seccomp profile is stored at:

    seccomp/runtime-restricted.json

The profile allows normal runtime initialization while explicitly denying high-risk system calls such as:

- `mount`
- `umount`
- `pivot_root`
- `bpf`
- `ptrace`
- `setns`
- `unshare`
- `swapon`
- `swapoff`
- kernel module operations
- system clock modification
- reboot operations

Validate the JSON:

    python3 -m json.tool \
      seccomp/runtime-restricted.json >/dev/null

Run a container with the profile:

    docker run --rm \
      --security-opt "seccomp=$PWD/seccomp/runtime-restricted.json" \
      alpine:latest \
      sh -c 'id && grep -E "Seccomp|Seccomp_filters" /proc/self/status'

Expected seccomp mode:

    Seccomp: 2

## Validate Syscall Blocking

Attempt a mount operation while granting `SYS_ADMIN`:

    docker run --rm \
      --cap-add SYS_ADMIN \
      --security-opt "seccomp=$PWD/seccomp/runtime-restricted.json" \
      alpine:latest \
      sh -c 'mkdir -p /mnt/test && mount -t tmpfs tmpfs /mnt/test'

The mount operation should fail because the custom seccomp profile blocks the syscall.

## AppArmor Policy

The AppArmor policy is stored at:

    apparmor/container-security-runtime

Install it on the host:

    sudo cp \
      apparmor/container-security-runtime \
      /etc/apparmor.d/container-security-runtime

Validate syntax:

    sudo apparmor_parser \
      --preprocess \
      /etc/apparmor.d/container-security-runtime \
      >/dev/null

Load the policy:

    sudo apparmor_parser \
      --replace \
      /etc/apparmor.d/container-security-runtime

Verify it is loaded:

    sudo aa-status |
      grep container-security-runtime

## Validate AppArmor Enforcement

Run a basic test:

    docker run --rm \
      --security-opt apparmor=container-security-runtime \
      alpine:latest \
      sh -c 'cat /proc/self/attr/current && id'

Test a restricted path:

    docker run --rm \
      --security-opt apparmor=container-security-runtime \
      alpine:latest \
      sh -c 'touch /root/restricted-file'

The write should be denied.

Test mount denial:

    docker run --rm \
      --cap-add SYS_ADMIN \
      --security-opt apparmor=container-security-runtime \
      alpine:latest \
      sh -c 'mkdir -p /mnt/test && mount -t tmpfs tmpfs /mnt/test'

The mount operation should be denied.

## Combined Defense-in-Depth Runtime

Run the service with all major controls:

    docker run --detach \
      --name defense-in-depth-runtime \
      --publish 127.0.0.1:8080:8080 \
      --security-opt "seccomp=$PWD/seccomp/runtime-restricted.json" \
      --security-opt apparmor=container-security-runtime \
      --security-opt no-new-privileges:true \
      --user 10001:10001 \
      --cap-drop ALL \
      --read-only \
      --tmpfs /tmp:rw,noexec,nosuid,size=32m \
      --memory 128m \
      --memory-swap 128m \
      --cpus 0.50 \
      --pids-limit 64 \
      --ulimit nofile=1024:1024 \
      container-security-runtime:1.0.0

Validate the application:

    curl http://127.0.0.1:8080/

Inspect active controls:

    docker exec defense-in-depth-runtime sh -c '
      id
      grep -E "Seccomp|Seccomp_filters|NoNewPrivs" /proc/self/status
      cat /proc/self/attr/current
    '

Inspect runtime configuration:

    docker inspect defense-in-depth-runtime \
      --format 'Security={{json .HostConfig.SecurityOpt}} CapDrop={{json .HostConfig.CapDrop}} ReadOnly={{.HostConfig.ReadonlyRootfs}} Memory={{.HostConfig.Memory}} NanoCPUs={{.HostConfig.NanoCpus}} Pids={{.HostConfig.PidsLimit}}'

## Filesystem Boundary Validation

Verify that the root filesystem is read-only:

    docker exec defense-in-depth-runtime \
      touch /unauthorized-write

The command should fail.

Verify that `/tmp` remains writable:

    docker exec defense-in-depth-runtime \
      touch /tmp/allowed-write

Verify that execution from `/tmp` is blocked:

    docker exec defense-in-depth-runtime \
      sh -c 'cp /bin/echo /tmp/test-executable && /tmp/test-executable hello'

The execution should fail because `/tmp` is mounted with `noexec`.

## Resource Limits

The runtime applies:

- Memory: 128 MiB
- Memory plus swap: 128 MiB
- CPU: 0.50 core
- PID limit: 64
- Open files: 1024
- Writable temporary storage: 32 MiB

Inspect Docker configuration:

    docker inspect defense-in-depth-runtime \
      --format 'Memory={{.HostConfig.Memory}} Swap={{.HostConfig.MemorySwap}} NanoCPUs={{.HostConfig.NanoCpus}} Pids={{.HostConfig.PidsLimit}}'

Inspect cgroup values:

    docker exec defense-in-depth-runtime sh -c '
      echo "memory.max=$(cat /sys/fs/cgroup/memory.max)"
      echo "pids.max=$(cat /sys/fs/cgroup/pids.max)"
      echo "cpu.max=$(cat /sys/fs/cgroup/cpu.max)"
      echo "nofile=$(ulimit -n)"
    '

Inspect live usage:

    docker stats defense-in-depth-runtime --no-stream

## Vulnerability Scanning

Three images are used for comparison:

- `security-comparison:outdated`
- `security-comparison:hardened`
- `container-security-runtime:1.0.0`

Create the Trivy cache volume:

    docker volume create container-security-trivy-cache

Scan an image:

    docker run --rm \
      --userns=host \
      --volume /var/run/docker.sock:/var/run/docker.sock:ro \
      --volume container-security-trivy-cache:/root/.cache/trivy \
      aquasec/trivy:latest \
      image \
      --severity HIGH,CRITICAL \
      --ignore-unfixed \
      --no-progress \
      --exit-code 0 \
      container-security-runtime:1.0.0

The scanner container uses `--userns=host` because daemon-wide user namespace remapping otherwise prevents it from accessing the Docker socket and its cache correctly.

The Docker socket is mounted read-only and only into the temporary scanner container.

## Secure Container Launcher

The reusable launcher is located at:

    scripts/secure-container-launcher.sh

Run it from the implementation root:

    ./scripts/secure-container-launcher.sh \
      container-security-runtime:1.0.0 \
      sh -c '
        id
        grep -E "Seccomp|Seccomp_filters|NoNewPrivs" /proc/self/status
        cat /proc/self/attr/current
      '

The launcher enforces:

- custom seccomp filtering
- AppArmor
- no-new-privileges
- UID/GID `10001`
- all Linux capabilities dropped
- memory and CPU limits
- PID restrictions
- file-descriptor limits
- read-only root filesystem
- writable but non-executable temporary storage

## Security Controls Demonstrated

- Docker user namespace remapping
- Host UID/GID translation
- Non-root application execution
- Custom seccomp filtering
- AppArmor mandatory access control
- No-new-privileges enforcement
- Complete capability removal
- Read-only root filesystem
- Controlled writable tmpfs
- Non-executable temporary storage
- Memory restriction
- CPU restriction
- PID restriction
- File-descriptor restriction
- cgroup v2 inspection
- Docker socket isolation
- Container health validation
- Image vulnerability scanning
- Reusable hardened runtime automation

## Tools Used

- Docker Engine
- Docker CLI
- Docker Buildx
- containerd
- Linux user namespaces
- seccomp
- AppArmor
- cgroup v2
- Trivy
- Python
- Alpine Linux
- Bash
- curl
- jq
- Git

## Real-World Use Case

These controls are relevant when deploying internal APIs, platform services, automation workers, CI/CD components, and machine-learning inference services.

A single security mechanism cannot protect every boundary. User namespaces reduce host-level UID risk, non-root image configuration limits application privileges, seccomp restricts kernel access, AppArmor controls filesystem and process behavior, capability removal limits privileged operations, and cgroup controls prevent resource exhaustion.

Together, these controls reduce the impact of application compromise and provide a repeatable security baseline for container deployment platforms.

## Lessons Learned

- Container root should not automatically be trusted as host root.
- User namespace remapping and non-root application execution solve different problems.
- Custom syscall allowlists can be fragile when runtime initialization requirements are incomplete.
- A targeted denylist can provide reliable enforcement while preserving required runtime behavior.
- AppArmor adds filesystem and process restrictions beyond standard Unix permissions.
- Capabilities should be removed by default and added only when required.
- Read-only filesystems prevent many persistence and tampering techniques.
- Writable temporary storage should be explicitly controlled.
- Memory, CPU, PID, and file-descriptor limits reduce denial-of-service risk.
- Vulnerability scanning complements runtime hardening but does not replace it.
- Security controls should be verified through executable tests and recorded evidence.

## Troubleshooting Log

### Docker Socket Permission Failure

The initial user lacked permission to access the Docker socket.

Resolution:

    sudo usermod -aG docker "$USER"
    newgrp docker

### Unsupported Per-Container User Namespace Mode

The Docker version rejected:

    --userns=private

Resolution:

Daemon-wide user namespace remapping was enabled through:

    {
      "userns-remap": "default"
    }

### Incomplete Seccomp Allowlist

The first custom seccomp allowlist prevented container initialization.

Initial failures included:

    fstatfs: operation not permitted

and:

    unable to get capability version from the kernel

The profile was redesigned as a targeted denylist that allows required runtime initialization while blocking high-risk operations.

### Trivy Cache Permission Failure

Daemon-wide user namespace remapping prevented the scanner container from writing to a host bind-mounted cache directory.

Resolution:

- A Docker-managed cache volume was created.
- The trusted temporary scanner used `--userns=host`.
- The Docker socket remained mounted read-only.

### AppArmor Profile Validation

The AppArmor profile was validated before loading:

    sudo apparmor_parser \
      --preprocess \
      /etc/apparmor.d/container-security-runtime

It was then loaded with:

    sudo apparmor_parser \
      --replace \
      /etc/apparmor.d/container-security-runtime

### Security Versus Compatibility

Overly restrictive profiles may prevent legitimate application startup.

Profiles should be adjusted using runtime evidence rather than disabling security controls broadly.

## Production Considerations

A production implementation should additionally include:

- signed images and provenance verification
- SBOM generation
- admission policies
- centralized vulnerability management
- continuous image rescanning
- immutable version deployment
- rootless Docker or Kubernetes where appropriate
- audit logging
- secret-management integration
- policy-as-code
- network segmentation
- runtime threat detection
- controlled exception procedures
