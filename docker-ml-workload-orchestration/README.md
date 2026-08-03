# Reproducible ML Containers and Workflow Orchestration

## What This Does

This implementation packages a deterministic scikit-learn training pipeline inside Docker and coordinates data preparation and model training through Docker Compose.

The standalone image writes a serialized model and structured metrics to a mounted directory. The distributed workflow uses separate containers, named volumes, dependency enforcement, and non-zero exit codes to prevent downstream execution when preprocessing fails.

## Architecture

    Standalone Training

    Environment Variables
            │
            ▼
    Multi-Stage Docker Image
            │
            ├── Load Dataset
            ├── Preprocess Data
            ├── Train Model
            └── Calculate Metrics
            │
            ▼
    Host-Mounted Output
    ├── breast-cancer-classifier.joblib
    └── metrics.json


    Distributed Workflow

    Data Preparation Container
            │
            ▼
    Prepared Data Volume
            │
            ▼
    Training Worker Container
            │
            ▼
    Results Volume
    ├── distributed-classifier.joblib
    └── results.json

## Prerequisites

- Docker Engine
- Docker Compose plugin
- Git
- Linux environment
- At least 4 GB of memory

## Setup and Reproduction

Build the standalone training image:

    docker build       --tag reproducible-ml-trainer:1.0.0       training/

Create an output directory:

    mkdir -p output
    chmod 0777 output

Run the training container:

    docker run --rm       --mount type=bind,source="$PWD/output",target=/app/output       reproducible-ml-trainer:1.0.0

Inspect the generated artifacts:

    ls -lh output
    cat output/metrics.json

Run the distributed workflow:

    docker compose down --volumes --remove-orphans 2>/dev/null || true
    docker compose build
    docker compose up       --abort-on-container-exit       --exit-code-from training-worker

Inspect service states:

    docker compose ps -a

Read the persisted training results:

    docker run --rm       --volume containerized-ml-training-results:/results:ro       alpine:3.22       cat /results/results.json

Validate upstream failure protection:

    docker compose       -f compose.yaml       -f compose.failure.yaml       up       --abort-on-container-exit       --exit-code-from data-preparation

The data-preparation container should exit with a non-zero status, and the training worker must not start.

## Tools Used

- Docker Engine
- Docker Compose
- Python 3.12
- scikit-learn
- joblib
- Logistic Regression
- Named Docker volumes
- Bind mounts
- JSON serialization

## Key Skills Demonstrated

- Multi-stage Docker image construction
- Reproducible model training with fixed random seeds
- Runtime configuration through environment variables
- Non-root container execution
- Model and metrics persistence
- Container dependency orchestration
- Shared-volume data exchange
- Failure propagation and exit-code validation

## Real-World Use Case

This architecture supports repeatable model training in CI pipelines, scheduled model refreshes, offline data processing, experiment execution, and on-premises ML environments. The same container contracts can later be transferred to Kubernetes Jobs or workflow orchestration platforms.

## Lessons Learned

- Fixed random seeds improve reproducibility across independent runs.
- Model artifacts must be stored outside ephemeral container filesystems.
- Downstream services should depend on successful upstream completion.
- Non-root containers require deliberate volume-permission handling.
- Failure paths must be tested alongside successful execution.

## Troubleshooting

### Docker Socket Permission

Add the current user to the Docker group:

    sudo usermod -aG docker "$USER"
    newgrp docker

### Bind-Mount Permission

Allow the non-root container user to write artifacts:

    chmod 0777 output

In production, replace broad permissions with explicit UID and GID ownership matching the container identity.
