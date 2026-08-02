# Container Runtime Diagnostics

## What This Does

This implementation provides a systematic troubleshooting environment for diagnosing container startup failures, log anomalies, port mapping errors, network connectivity problems, resource pressure, and out-of-memory termination.

It combines Docker logs, exec, inspect, stats, network inspection, controlled failure scenarios, an ephemeral diagnostic image, time-series metrics, secret-aware reporting, and automated multi-container triage.

The workflow creates reproducible evidence for each failure instead of relying on manual observation or modifying running application containers.

## Architecture

    Controlled Container Scenarios
                |
                v
    +-----------------------------+
    | Runtime States              |
    |                             |
    | Healthy Service             |
    | Noisy Log Stream            |
    | Startup Failure             |
    | Port Misconfiguration       |
    | CPU Load                    |
    | Memory Load                 |
    | OOM Termination             |
    +--------------+--------------+
                   |
                   v
    +-----------------------------+
    | Diagnostic Collection       |
    |                             |
    | docker logs                 |
    | docker exec                 |
    | docker inspect              |
    | docker stats                |
    | docker top                  |
    | Docker Network Inspection   |
    +--------------+--------------+
                   |
         +---------+----------+
         |                    |
         v                    v
    +------------+     +----------------------+
    | Ephemeral  |     | Automated Reporting  |
    | Toolkit    |     |                      |
    |            |     | Secret Redaction     |
    | DNS        |     | Failure Hints        |
    | TCP        |     | Scoped Triage        |
    | HTTP       |     | Metric Collection    |
    | Routes     |     | Evidence Bundles     |
    +------------+     +----------------------+

## Directory Structure

    container-runtime-diagnostics/
    ├── README.md
    ├── debug-toolkit/
    │   └── Dockerfile
    ├── scripts/
    │   ├── collect-container-metrics.sh
    │   ├── debug-container.sh
    │   └── triage-debugging-scope.sh
    ├── logs/
    │   ├── memory-load.log
    │   ├── noisy-service-all.log
    │   ├── noisy-service-recent.log
    │   ├── noisy-service-tail.log
    │   ├── oom-debug-test.log
    │   ├── port-conflict-command.txt
    │   └── startup-failure.log
    ├── metrics/
    │   ├── baseline-stats.txt
    │   ├── container-metrics.csv
    │   ├── cpu-load-stats.txt
    │   ├── final-stats.txt
    │   └── memory-load-stats.txt
    └── reports/
        ├── container-inspection-summary.txt
        ├── debugging-network-inspect.json
        ├── debug-toolkit-network-test.txt
        ├── ephemeral-network-diagnostics.txt
        ├── failure-diagnosis-matrix.txt
        ├── final-debugging-report.txt
        ├── final-webserver-diagnostic.txt
        ├── misconfigured-port-final-diagnosis.txt
        ├── oom-diagnosis.txt
        ├── oom-full-report.txt
        ├── performance-summary.txt
        ├── port-mapping-diagnosis.txt
        ├── redacted-environment.txt
        ├── runtime-diagnostic-snapshot.txt
        ├── startup-failure-diagnosis.txt
        ├── startup-failure-full-report.txt
        ├── webserver-debug-report.txt
        └── final-triage/

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
- Standard Linux networking and process utilities
- Available host ports `3000`, `8080`, `8081`, and `9090`

## Environment Verification

Verify the required tools:

    docker --version
    docker compose version
    docker buildx version
    curl --version
    jq --version
    python3 --version
    ss --version
    ip -V

Verify Docker access:

    docker info

If Docker access is denied:

    sudo usermod -aG docker "$USER"
    newgrp docker

## Diagnostic Scenarios

The implementation uses several controlled containers:

- `webserver-debug` — healthy Nginx service
- `env-debug` — environment-variable inspection and redaction
- `noisy-service` — mixed informational, warning, and error logs
- `misconfigured-web` — incorrect host-to-container port mapping
- `startup-failure` — missing executable during container initialization
- `debug-config` — explicit resource limits, restart policy, and tmpfs
- `debug-cpu-load` — controlled CPU utilization
- `debug-memory-load` — controlled memory allocation
- `oom-debug-test` — deliberate kernel OOM termination

All generated containers use this label:

    debugging.scope=container-debugging-engineering

This makes resource discovery, reporting, and cleanup safely scoped.

## Log Analysis

Capture all logs:

    docker logs noisy-service

View timestamped logs:

    docker logs \
      --timestamps \
      noisy-service

View the latest entries:

    docker logs \
      --tail 10 \
      noisy-service

View recent logs:

    docker logs \
      --since 10s \
      --timestamps \
      noisy-service

Filter warnings:

    docker logs noisy-service 2>&1 |
      grep -i WARN

Filter errors:

    docker logs noisy-service 2>&1 |
      grep -i ERROR

The noisy service writes informational messages to standard output and warning or error messages to standard error.

## Live Container Debugging

Inspect process identity:

    docker exec webserver-debug id

Inspect the working directory:

    docker exec webserver-debug pwd

Inspect processes:

    docker exec webserver-debug ps

Inspect filesystem usage:

    docker exec webserver-debug df -h

Inspect the Nginx configuration:

    docker exec webserver-debug \
      sh -c 'sed -n "1,80p" /etc/nginx/conf.d/default.conf'

The workflow avoids installing tools inside running application containers. Diagnostic utilities are provided through a separate ephemeral image.

## Container Inspection

Inspect runtime state:

    docker inspect webserver-debug \
      --format 'Status={{.State.Status}} Running={{.State.Running}} ExitCode={{.State.ExitCode}}'

Inspect image and command:

    docker inspect webserver-debug \
      --format 'Image={{.Config.Image}} Entrypoint={{json .Config.Entrypoint}} Command={{json .Config.Cmd}}'

Inspect port mappings:

    docker inspect webserver-debug \
      --format '{{json .NetworkSettings.Ports}}' |
      python3 -m json.tool

Inspect network membership:

    docker inspect webserver-debug \
      --format '{{json .NetworkSettings.Networks}}' |
      python3 -m json.tool

Inspect mounts:

    docker inspect debug-config \
      --format '{{json .Mounts}}' |
      python3 -m json.tool

Inspect resource limits:

    docker inspect debug-config \
      --format 'Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}} NanoCPUs={{.HostConfig.NanoCpus}} PidsLimit={{.HostConfig.PidsLimit}}'

Inspect restart and logging configuration:

    docker inspect debug-config \
      --format 'RestartPolicy={{.HostConfig.RestartPolicy.Name}} LogDriver={{.HostConfig.LogConfig.Type}}'

## Startup Failure Diagnosis

The startup failure uses a nonexistent executable.

Inspect the container:

    docker ps -a \
      --filter name=startup-failure

Inspect the recorded runtime error:

    docker inspect startup-failure \
      --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} Command={{json .Config.Cmd}}'

Inspect logs:

    docker logs startup-failure

A nonempty `.State.Error` value identifies failure during runtime initialization before the application process started.

## Port Mapping Diagnosis

The misconfigured service publishes:

    [IP_ADDRESS]:9090 -> container port 8080

Nginx listens inside the container on port `80`.

Inspect the mapping:

    docker inspect misconfigured-web \
      --format '{{json .NetworkSettings.Ports}}' |
      python3 -m json.tool

Inspect the actual listener configuration:

    docker exec misconfigured-web \
      sh -c 'grep -E "listen[[:space:]]" /etc/nginx/conf.d/default.conf'

The corrected publication is:

    [IP_ADDRESS]:9090:80

## Port Conflict Diagnosis

Port `8080` is already owned by the healthy web container.

Inspect the host listener:

    ss -ltnp |
      grep ':8080'

Inspect the container that owns the mapping:

    docker inspect webserver-debug \
      --format '{{json .NetworkSettings.Ports}}' |
      python3 -m json.tool

Attempting to start another container on the same host address and port should be rejected by Docker.

## Runtime Performance Monitoring

View a one-time snapshot:

    docker stats --no-stream

View selected containers:

    docker stats \
      --no-stream \
      webserver-debug \
      noisy-service \
      debug-config

Use a custom format:

    docker stats \
      --no-stream \
      --format 'Container={{.Name}} CPU={{.CPUPerc}} Memory={{.MemUsage}} MemoryPercent={{.MemPerc}} Network={{.NetIO}} Block={{.BlockIO}} PIDs={{.PIDs}}'

## Time-Series Metric Collection

The metrics collector is located at:

    scripts/collect-container-metrics.sh

Usage:

    ./scripts/collect-container-metrics.sh \
      metrics/container-metrics.csv \
      5 \
      2

Arguments:

- output file
- number of samples
- interval in seconds

The CSV contains:

- timestamp
- container name
- CPU percentage
- memory usage
- memory percentage
- network I/O
- block I/O
- PID count

## Network Diagnostics

Inspect the diagnostic network:

    docker network inspect debugging-network

Inspect container addresses:

    docker inspect webserver-debug \
      --format '{{json .NetworkSettings.Networks}}' |
      python3 -m json.tool

Test Docker DNS:

    docker run --rm \
      --network debugging-network \
      alpine:latest \
      getent hosts webserver-debug

Test HTTP connectivity:

    docker run --rm \
      --network debugging-network \
      alpine:latest \
      wget --quiet --spider http://webserver-debug/

## Ephemeral Diagnostic Image

The diagnostic image includes:

- Bash
- curl
- DNS utilities
- netcat
- iproute2
- ping
- jq
- process utilities
- strace
- tcpdump

Build it:

    cd debug-toolkit

    docker build \
      --file Dockerfile \
      --tag container-diagnostic-toolkit:1.0.0 \
      .

Inspect its runtime identity:

    docker image inspect \
      container-diagnostic-toolkit:1.0.0 \
      --format 'User={{.Config.User}} SizeBytes={{.Size}}'

The image runs as UID and GID `65534`.

Use it on the diagnostic network:

    docker run --rm \
      --network debugging-network \
      --cap-drop ALL \
      --security-opt no-new-privileges:true \
      container-diagnostic-toolkit:1.0.0 \
      -c '
        nslookup webserver-debug
        nc -zv webserver-debug 80
        curl -I http://webserver-debug/
        ip route
      '

## Out-of-Memory Diagnosis

The controlled OOM container has:

- memory limit: 48 MiB
- memory plus swap: 48 MiB
- CPU limit: 0.25 core
- PID limit: 32

Inspect the result:

    docker inspect oom-debug-test \
      --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} Memory={{.HostConfig.Memory}}'

Expected evidence:

    OOMKilled=true

Inspect allocation logs:

    docker logs oom-debug-test

This distinguishes an application exception from termination by the kernel memory controller.

## Automated Container Report

The diagnostic script is located at:

    scripts/debug-container.sh

Usage:

    ./scripts/debug-container.sh <container-name>

Save the report:

    ./scripts/debug-container.sh \
      webserver-debug \
      reports/webserver-debug-report.txt

The report includes:

- container state
- exit code
- OOM state
- restart count
- runtime errors
- timestamps
- image and command
- resource limits
- security settings
- ports
- networks
- mounts
- redacted environment variables
- recent logs
- live resource snapshot
- process snapshot
- diagnostic hints

## Sensitive Environment Redaction

Variables with names containing terms such as the following are redacted:

- `PASSWORD`
- `PASSWD`
- `TOKEN`
- `SECRET`
- `API_KEY`
- `PRIVATE_KEY`
- `ACCESS_KEY`

Example:

    API_TOKEN=[REDACTED]

The script must not be treated as a substitute for proper secret management. It reduces accidental exposure in generated reports.

## Scoped Multi-Container Triage

The triage script is located at:

    scripts/triage-debugging-scope.sh

Usage:

    ./scripts/triage-debugging-scope.sh \
      debugging.scope=container-debugging-engineering \
      reports/triage

The script:

- discovers containers by label
- generates an individual report for every match
- writes the reports into a dedicated directory
- avoids touching unrelated containers

## Failure Diagnosis Matrix

The generated matrix compares:

- current state
- exit code
- OOM status
- restart count
- runtime error

This provides a compact incident overview before deeper analysis.

## Systematic Troubleshooting Order

Use this order during container incidents:

    1. docker ps -a
    2. docker logs
    3. docker inspect
    4. docker stats
    5. docker top
    6. docker network inspect
    7. docker exec
    8. Ephemeral diagnostic image
    9. Host listener and filesystem checks
    10. Correlate evidence before changing configuration

This sequence begins with low-impact evidence collection and moves toward deeper runtime inspection.

## Tools Used

- Docker Engine
- Docker CLI
- Docker Buildx
- Docker Compose
- Docker logs
- Docker exec
- Docker inspect
- Docker stats
- Docker top
- Docker networks
- Nginx Alpine
- Alpine Linux
- Python Alpine
- curl
- jq
- Bash
- sed
- awk
- ss
- netcat
- DNS utilities
- strace
- tcpdump
- Git

## Skills Demonstrated

- Container state diagnosis
- Structured log analysis
- Standard output and error investigation
- Interactive and non-interactive runtime inspection
- Container metadata analysis
- Port mapping troubleshooting
- Host port conflict investigation
- Docker DNS verification
- Container-to-container connectivity testing
- CPU and memory monitoring
- Time-series metric collection
- Resource-limit inspection
- OOM termination analysis
- Process inspection
- Ephemeral debugging
- Sensitive-value redaction
- Automated incident reporting
- Scoped fleet triage
- Non-destructive diagnostics

## Real-World Use Case

These techniques are applicable to APIs, web services, automation workers, CI runners, platform components, and machine-learning inference containers.

A production incident may involve a container that never starts, repeatedly exits, cannot reach another service, listens on the wrong port, consumes unexpected resources, or is terminated by the kernel.

This implementation demonstrates how to collect evidence systematically, distinguish configuration problems from application problems, and produce reports suitable for operational handoff.

## Lessons Learned

- Container status should be checked before attempting live execution.
- Runtime errors in `docker inspect` can explain failures that produce no application logs.
- Logs are useful only when applications write to standard output and standard error.
- Explicit host and container ports must both match the application listener.
- `NanoCpus` is the correct field for an explicit `--cpus` limit.
- OOM termination must be verified through `.State.OOMKilled`.
- Diagnostic tooling should not be installed inside immutable application containers.
- Ephemeral tools preserve reproducibility and reduce runtime drift.
- Resource metrics are more useful when captured over time.
- Environment inspection can expose credentials and must include redaction.
- Cleanup and reporting should be scoped through labels.
- Troubleshooting should collect evidence before changing the system.

## Troubleshooting Log

### Docker Socket Access

The initial user lacked Docker daemon access.

Resolution:

    sudo usermod -aG docker "$USER"
    newgrp docker

### JSON Parsing Failure

A formatted inspect command produced:

    Mounts=[...]

and was piped into:

    python3 -m json.tool

The text prefix made the result invalid JSON.

Resolution:

    docker inspect debug-config \
      --format '{{json .Mounts}}' |
      python3 -m json.tool

### Startup Failure Without Application Logs

The missing executable prevented the application process from starting.

The root cause was found in:

    .State.Error

rather than application logs.

### Incorrect Port Mapping

The host forwarded port `9090` to container port `8080`, while Nginx listened on port `80`.

Correct configuration:

    [IP_ADDRESS]:9090:80

### Port Conflict

A second container attempted to claim host port `8080`, which was already bound by the healthy web service.

The conflict was confirmed with:

    ss -ltnp
    docker inspect

### Controlled OOM Termination

The Python allocation process exceeded its 48 MiB memory limit.

The container was terminated with:

    OOMKilled=true

### Sensitive Environment Variable

A sample token was present in the environment-debug container.

Generated reports replaced the value with:

    [REDACTED]

### Modifying Running Containers

Installing packages inside application containers was intentionally avoided.

A separate diagnostic image was used instead.

## Production Considerations

A production extension should include:

- centralized log aggregation
- structured JSON logging
- distributed tracing
- metrics collection through Prometheus
- dashboards and alerting
- container event monitoring
- log retention policies
- correlation IDs
- automated incident bundles
- Kubernetes ephemeral containers
- runtime security monitoring
- controlled access to diagnostic tooling
- secret-management integration
- evidence retention and access policies
