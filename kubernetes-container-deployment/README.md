# Kubernetes Container Deployment

## What This Does

This implementation builds a custom Nginx container image and deploys it to a local Kubernetes cluster using declarative manifests. It demonstrates replicated workloads, service networking, health probes, resource governance, horizontal scaling, rolling updates, metrics, and operational troubleshooting.

The workflow represents the core container-to-Kubernetes delivery process used for web services, APIs, internal platforms, and containerized AI applications.

## Architecture

    Client Request
          |
          v
    NodePort Service :30080
          |
          v
    Kubernetes Service
          |
          v
    ┌─────────────────────────────┐
    │ Deployment: container-web   │
    │                             │
    │  ┌────────┐  ┌────────┐     │
    │  │ Pod 1  │  │ Pod 2  │     │
    │  │ Nginx  │  │ Nginx  │     │
    │  └────────┘  └────────┘     │
    │                             │
    │ Readiness and liveness      │
    │ CPU and memory controls     │
    │ Rolling update strategy     │
    └─────────────────────────────┘
          |
          v
    Minikube Kubernetes Node
          |
          v
    containerd Runtime

## Prerequisites

- Linux
- Docker Engine
- kubectl
- Minikube
- Git
- curl
- At least 3 CPU cores
- At least 6 GB available memory
- Docker daemon access for the current user

## Setup

Verify the required tools:

```bash
docker --version
kubectl version --client
minikube version
```

Start Minikube:

```bash
minikube start \
  --driver=docker \
  --container-runtime=containerd \
  --cpus=3 \
  --memory=6144mb
```

Verify the cluster:

```bash
minikube status
kubectl get nodes
kubectl get pods -n kube-system
```

## How to Reproduce

Clone the repository and enter this implementation directory:

```bash
git clone https://github.com/bilalfayyaz11/container-platform-engineering.git
cd container-platform-engineering/kubernetes-container-deployment
```

Build the image inside Minikube:

```bash
minikube image build \
  -t container-web:v1.0 \
  .
```

Deploy the application:

```bash
kubectl apply -f app-deployment.yaml
kubectl apply -f app-service.yaml
```

Wait for the rollout:

```bash
kubectl rollout status \
  deployment/container-web \
  --timeout=180s
```

Verify the resources:

```bash
kubectl get deployment container-web
kubectl get pods -l app=container-web -o wide
kubectl get service container-web
kubectl get endpoints container-web
```

Test the NodePort endpoint:

```bash
MINIKUBE_IP=$(minikube ip)
curl "http://${MINIKUBE_IP}:30080"
```

Scale the deployment:

```bash
kubectl scale deployment/container-web --replicas=5
kubectl get pods -l app=container-web

kubectl scale deployment/container-web --replicas=2
```

Build and deploy a new image version:

```bash
minikube image build \
  -t container-web:v2.0 \
  .

kubectl set image \
  deployment/container-web \
  web=container-web:v2.0

kubectl rollout status deployment/container-web
```

Inspect and troubleshoot a pod:

```bash
POD_NAME=$(kubectl get pods \
  -l app=container-web \
  -o jsonpath='{.items[0].metadata.name}')

kubectl describe pod "$POD_NAME"
kubectl logs "$POD_NAME"
kubectl exec "$POD_NAME" -- \
  ls -l /usr/share/nginx/html
```

Test direct pod access:

```bash
kubectl port-forward pod/"$POD_NAME" 8080:80
```

In another terminal:

```bash
curl http://127.0.0.1:8080
```

Enable resource metrics:

```bash
minikube addons enable metrics-server
kubectl top nodes
kubectl top pods --containers
```

Remove the application:

```bash
kubectl delete -f app-service.yaml
kubectl delete -f app-deployment.yaml
```

Remove the cluster:

```bash
minikube stop
minikube delete
```

## Tools Used

- Kubernetes
- Minikube
- kubectl
- Docker
- containerd
- Nginx
- YAML
- Linux
- Bash
- curl
- Git

## Key Skills Demonstrated

- Built a custom container image for Kubernetes
- Created declarative Deployment and Service manifests
- Configured NodePort service networking
- Implemented readiness and liveness probes
- Applied CPU and memory requests and limits
- Scaled application replicas horizontally
- Performed a controlled rolling image update
- Inspected pod events, logs, files, and runtime state
- Used port forwarding for direct workload testing
- Enabled Kubernetes resource metrics
- Managed the full workload and cluster lifecycle

## Real-World Use Case

This workflow can be used to deploy internal applications, APIs, web services, model-serving endpoints, and operational tools to Kubernetes. Platform and AI engineering teams can use the same pattern to define resource requirements, validate application health, scale replicas, release new versions safely, and diagnose failures without manually managing individual containers.

## Lessons Learned

- Docker daemon access must be verified before Minikube uses the Docker driver.
- Minikube with containerd should use `minikube image build` rather than redirecting Docker through `docker-env`.
- `imagePullPolicy: Never` allows Kubernetes to use images loaded directly into the local cluster runtime.
- Readiness probes control traffic eligibility, while liveness probes detect containers that need restarting.
- A Deployment maintains the desired replica count and manages rolling replacements.
- A single-node Minikube environment validates workload behavior but does not provide node-level high availability.

## Troubleshooting Log

### Docker Socket Access

Minikube initially failed because the active shell did not have permission to access `/var/run/docker.sock`.

Resolution:

```bash
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
```

### Container Runtime Compatibility

The original workflow used:

```bash
eval $(minikube docker-env)
```

The cluster used containerd, so the image was built directly into Minikube instead:

```bash
minikube image build \
  -t container-web:v1.0 \
  .
```

### Local Image Resolution

The Deployment was configured to use the locally built image:

```yaml
image: container-web:v1.0
imagePullPolicy: Never
```

### Kubernetes API Connection Errors

`kubectl` initially attempted to connect to `localhost:8080` because Minikube had failed before creating a Kubernetes context. Starting Minikube successfully generated the context and resolved the API connection.

### Workload Health

Readiness and liveness probes were added to validate application availability and automatically recover unhealthy containers:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: http

livenessProbe:
  httpGet:
    path: /
    port: http
```
