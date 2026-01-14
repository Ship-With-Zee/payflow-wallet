# MicroK8s Deployment Guide - PayFlow Wallet

> **Purpose**: Step-by-step guide to deploy PayFlow microservices to MicroK8s

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Docker Cleanup](#docker-cleanup)
3. [MicroK8s Setup](#microk8s-setup)
4. [Build & Push Images](#build--push-images)
5. [Create Kubernetes Manifests](#create-kubernetes-manifests)
6. [Deploy to MicroK8s](#deploy-to-microk8s)
7. [Verify Deployment](#verify-deployment)
8. [Access Application](#access-application)
9. [Troubleshooting](#troubleshooting)

---

## Platform Overview

MicroK8s can run on different platforms with different architectures:

| Platform | Architecture | VM Required | Performance | Ease of Setup |
|----------|-------------|-------------|-------------|--------------|
| **macOS** | Multipass VM | ✅ Yes | Good | Easy |
| **Windows** | Multipass VM | ✅ Yes | Good | Moderate |
| **Windows** | WSL2 | ⚠️ WSL2 | Better | Moderate |
| **Linux** | Native | ❌ No | Best | Easy |

### Platform-Specific Notes

**macOS**:
- MicroK8s runs in a Multipass VM automatically
- VM is managed by MicroK8s (`microk8s-vm`)
- Access VM: `multipass shell microk8s-vm`
- File transfers: `multipass transfer`

**Windows (Multipass)**:
- Requires Multipass installation
- Needs VirtualBox or Hyper-V
- VM must be created manually
- File transfers: `multipass transfer`

**Windows (WSL2)**:
- Uses Windows Subsystem for Linux 2
- Better performance than Multipass VM
- Direct access to MicroK8s (no VM commands)
- File paths: `/mnt/c/...` for Windows drives

**Linux (Native)**:
- Direct installation on host
- Best performance
- No VM overhead
- Standard Linux commands

---

## Prerequisites

### Required Tools
```bash
# Check if Docker is installed
docker --version

# Check if MicroK8s is installed
microk8s version

# Check if kubectl is available
kubectl version --client
```

### Install MicroK8s (Platform-Specific)

#### macOS (Runs in Multipass VM)
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install MicroK8s via Homebrew
brew install ubuntu/microk8s/microk8s

# Install MicroK8s (creates Multipass VM automatically)
microk8s install

# Note: On macOS, MicroK8s runs inside a Multipass VM named "microk8s-vm"
# No need for usermod (that's Linux-specific)
```

**macOS VM Details**:
- MicroK8s runs in a Multipass VM named `microk8s-vm`
- VM is automatically created during `microk8s install`
- Access VM: `multipass shell microk8s-vm`
- VM resources: Default 2GB RAM, 1 CPU (can be adjusted)

#### Windows (Runs in Multipass VM or WSL2)

**Option 1: Using Multipass (Recommended)**
```powershell
# Install Multipass for Windows
# Download from: https://multipass.run/install

# Install MicroK8s via Multipass
multipass launch --name microk8s-vm --cpus 2 --mem 4G --disk 20G

# Enter the VM
multipass shell microk8s-vm

# Inside the VM, install MicroK8s
sudo snap install microk8s --classic

# Add user to microk8s group
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s

# Exit VM
exit
```

**Option 2: Using WSL2 (Windows Subsystem for Linux)**
```powershell
# Install WSL2 (if not installed)
wsl --install

# Install Ubuntu from Microsoft Store
# Then open Ubuntu terminal

# Inside WSL2 Ubuntu:
sudo snap install microk8s --classic

# Add user to microk8s group
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s
```

**Windows VM Considerations**:
- Multipass VM requires VirtualBox or Hyper-V
- WSL2 uses Hyper-V backend
- Ensure virtualization is enabled in BIOS
- Allocate sufficient resources (4GB+ RAM recommended)

#### Linux (Native Installation)
```bash
# Install MicroK8s via snap
sudo snap install microk8s --classic

# Add user to microk8s group
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube

# Apply group changes (logout/login or use newgrp)
newgrp microk8s

# Or logout and login again
```

**Linux Native vs VM**:
- Native: Direct installation, better performance
- VM: Isolation, easier cleanup, cross-platform consistency

---

## VM Management (Windows & macOS)

### Multipass VM Commands

**List VMs**:
```bash
# macOS / Linux
multipass list

# Windows (PowerShell)
multipass list
```

**Access VM Shell**:
```bash
# macOS / Linux
multipass shell microk8s-vm

# Windows (PowerShell)
multipass shell microk8s-vm
```

**Transfer Files to VM**:
```bash
# macOS / Linux
multipass transfer /local/path/file.txt microk8s-vm:/remote/path/file.txt

# Windows (PowerShell)
multipass transfer C:\local\path\file.txt microk8s-vm:/remote/path/file.txt
```

**Execute Commands in VM**:
```bash
# macOS / Linux
multipass exec microk8s-vm -- command

# Windows (PowerShell)
multipass exec microk8s-vm -- command
```

**Stop/Start VM**:
```bash
# Stop VM
multipass stop microk8s-vm

# Start VM
multipass start microk8s-vm

# Delete VM (⚠️ destroys all data)
multipass delete microk8s-vm
multipass purge
```

**VM Resource Management**:
```bash
# Check VM resources
multipass info microk8s-vm

# Resize VM (requires stop first)
multipass stop microk8s-vm
multipass set local.microk8s-vm.cpus=4
multipass set local.microk8s-vm.memory=8G
multipass start microk8s-vm
```

### WSL2 Management (Windows)

**List WSL Distributions**:
```powershell
wsl --list --verbose
```

**Start/Stop WSL**:
```powershell
# Start WSL
wsl

# Stop WSL
wsl --shutdown
```

**Access from Windows**:
```powershell
# Run command in WSL from PowerShell
wsl microk8s status

# Access files
# Windows: C:\Users\<User>\...
# WSL: /mnt/c/Users/<User>/...
```

---

## Docker Cleanup

### Step 1: Start Docker Desktop

#### macOS
```bash
# Open Docker Desktop application
open -a Docker

# Wait for Docker to start (check whale icon in menu bar)
# Or verify with:
docker ps
```

#### Windows
```powershell
# Start Docker Desktop from Start Menu
# Or verify with:
docker ps

# If Docker Desktop is not installed:
# Download from: https://www.docker.com/products/docker-desktop
```

#### Linux
```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Verify
docker ps
```

### Step 2: Stop All PayFlow Containers
```bash
cd "/Users/mac/Desktop/Coaching/PayFlow Wallet 2"

# Stop and remove all containers, networks, volumes
docker-compose down -v

# Expected output:
# [+] Running 8/8
#  ✔ Container payflowwallet2-frontend-1            Removed
#  ✔ Container payflowwallet2-api-gateway-1         Removed
#  ✔ Container payflowwallet2-wallet-service-1      Removed
#  ✔ Container payflowwallet2-transaction-service-1 Removed
#  ✔ Container payflowwallet2-notification-service-1 Removed
#  ✔ Container payflowwallet2-auth-service-1        Removed
#  ✔ Container payflowwallet2-postgres-1            Removed
#  ✔ Container payflowwallet2-rabbitmq-1            Removed
#  ✔ Container payflowwallet2-redis-1               Removed
#  ✔ Volume payflowwallet2_postgres_data            Removed
#  ✔ Volume payflowwallet2_redis_data               Removed
#  ✔ Volume payflowwallet2_rabbitmq_data            Removed
```

### Step 3: Remove PayFlow Images
```bash
# List all PayFlow images
docker images | grep payflowwallet2

# Remove all PayFlow images
docker rmi $(docker images | grep payflowwallet2 | awk '{print $3}')

# Or remove one by one:
docker rmi payflowwallet2-frontend:latest
docker rmi payflowwallet2-api-gateway:latest
docker rmi payflowwallet2-auth-service:latest
docker rmi payflowwallet2-wallet-service:latest
docker rmi payflowwallet2-transaction-service:latest
docker rmi payflowwallet2-notification-service:latest
```

### Step 4: Clean Up Dangling Resources
```bash
# Remove unused containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f
```

### Step 5: Verify Cleanup
```bash
# Should show no PayFlow resources
docker ps -a | grep payflow
docker images | grep payflow
docker volume ls | grep payflow
```

---

## MicroK8s Setup

### Step 1: Start MicroK8s

#### macOS (VM-based)
```bash
# Start MicroK8s (starts the Multipass VM if needed)
microk8s start

# Wait for it to be ready
microk8s status --wait-ready

# Check VM status
multipass list
```

#### Windows (Multipass VM)
```powershell
# Start the Multipass VM
multipass start microk8s-vm

# Enter the VM
multipass shell microk8s-vm

# Inside VM, start MicroK8s
microk8s start
microk8s status --wait-ready

# Exit VM
exit
```

#### Windows (WSL2)
```bash
# Open WSL2 Ubuntu terminal
# MicroK8s should start automatically, or:
microk8s start
microk8s status --wait-ready
```

#### Linux (Native)
```bash
# Start MicroK8s
microk8s start

# Wait for it to be ready
microk8s status --wait-ready
```

### Step 2: Enable Required Add-ons
```bash
# Enable DNS (required for service discovery)
microk8s enable dns

# Enable storage (for PersistentVolumes)
microk8s enable storage

# Enable registry (for local images)
microk8s enable registry

# Enable ingress (for external access)
microk8s enable ingress

# Enable metrics-server (for monitoring)
microk8s enable metrics-server

# Verify add-ons
microk8s status
```

**Expected Output**:
```
microk8s is running
high-availability: no
  datastore master nodes: 127.0.0.1:19001
  datastore standby nodes: none
addons:
  enabled:
    dns                  # (core) CoreDNS
    ha-cluster           # (core) Configure high availability on the current node
    helm                 # (core) Helm - the package manager for Kubernetes
    helm3                # (core) Helm 3 - the package manager for Kubernetes
    hostpath-storage     # (core) Storage class; allocates storage from host directory
    ingress              # (core) Ingress controller for external access
    metrics-server       # (core) K8s Metrics Server for API access to service metrics
    registry             # (core) Private image registry exposed on localhost:32000
    storage              # (core) Alias to hostpath-storage add-on
```

### Step 3: Configure kubectl

#### macOS / Linux
```bash
# Set up kubectl to use MicroK8s
microk8s kubectl config view --raw > ~/.kube/microk8s-config

# Set as default context (optional)
export KUBECONFIG=~/.kube/microk8s-config

# Or create alias (add to ~/.zshrc or ~/.bashrc)
alias kubectl='microk8s kubectl'

# Verify connection
kubectl cluster-info
kubectl get nodes
```

#### Windows (PowerShell)
```powershell
# Set up kubectl to use MicroK8s
# If using Multipass VM:
multipass exec microk8s-vm -- microk8s kubectl config view --raw > $env:USERPROFILE\.kube\microk8s-config

# Set environment variable
$env:KUBECONFIG = "$env:USERPROFILE\.kube\microk8s-config"

# Or if using WSL2, use WSL commands:
wsl microk8s kubectl config view --raw > $env:USERPROFILE\.kube\microk8s-config

# Verify connection
kubectl cluster-info
kubectl get nodes
```

#### Windows (WSL2)
```bash
# Inside WSL2 Ubuntu terminal:
microk8s kubectl config view --raw > ~/.kube/microk8s-config
export KUBECONFIG=~/.kube/microk8s-config

# Verify
kubectl cluster-info
kubectl get nodes
```

### Step 4: Create Namespace
```bash
# Create dedicated namespace for PayFlow
kubectl create namespace payflow

# Set as default namespace (optional)
kubectl config set-context --current --namespace=payflow

# Verify
kubectl get namespaces
```

---

## Build & Push Images to Docker Hub

**Why Docker Hub?** Kubernetes needs images from a registry it can access. Docker Hub is the most common choice for learning and development.

**Learning Path:**
1. **Phase 1** (you already did this): Built images locally, ran with Docker Compose
2. **Phase 4** (you're here now): Push images to Docker Hub, use them in Kubernetes

### Step 1: Build Images Locally

**First, build all images on your local machine:**

```bash
cd "/Users/mac/Desktop/Coaching/PayFlow Wallet 2"

# Build all services using docker-compose
docker-compose build

# This creates images with names like:
# - payflowwallet2-frontend:latest
# - payflowwallet2-api-gateway:latest
# - payflowwallet2-auth-service:latest
# - payflowwallet2-wallet-service:latest
# - payflowwallet2-transaction-service:latest
# - payflowwallet2-notification-service:latest
```

**Verify images were built:**
```bash
docker images | grep payflowwallet2
```

### Step 2: Create Docker Hub Account (If You Don't Have One)

1. Go to https://hub.docker.com
2. Sign up for a free account
3. Remember your username (you'll need it)

### Step 3: Login to Docker Hub

```bash
# Login to Docker Hub
docker login

# Enter your Docker Hub username and password when prompted
```

**Expected Output:**
```
Login Succeeded
```

### Step 4: Tag Images for Docker Hub

**Tag images with your Docker Hub username:**

```bash
# Replace 'yourusername' with your actual Docker Hub username
DOCKERHUB_USERNAME="yourusername"

# Tag each image
docker tag payflowwallet2-frontend:latest ${DOCKERHUB_USERNAME}/payflow-frontend:latest
docker tag payflowwallet2-api-gateway:latest ${DOCKERHUB_USERNAME}/payflow-api-gateway:latest
docker tag payflowwallet2-auth-service:latest ${DOCKERHUB_USERNAME}/payflow-auth-service:latest
docker tag payflowwallet2-wallet-service:latest ${DOCKERHUB_USERNAME}/payflow-wallet-service:latest
docker tag payflowwallet2-transaction-service:latest ${DOCKERHUB_USERNAME}/payflow-transaction-service:latest
docker tag payflowwallet2-notification-service:latest ${DOCKERHUB_USERNAME}/payflow-notification-service:latest
```

**Or use the provided script:**
```bash
# Make script executable (first time only)
chmod +x push-to-dockerhub.sh

# First, tag images with your username
DOCKERHUB_USERNAME="yourusername"
docker tag payflowwallet2-frontend:latest ${DOCKERHUB_USERNAME}/payflow-frontend:latest
docker tag payflowwallet2-api-gateway:latest ${DOCKERHUB_USERNAME}/payflow-api-gateway:latest
docker tag payflowwallet2-auth-service:latest ${DOCKERHUB_USERNAME}/payflow-auth-service:latest
docker tag payflowwallet2-wallet-service:latest ${DOCKERHUB_USERNAME}/payflow-wallet-service:latest
docker tag payflowwallet2-transaction-service:latest ${DOCKERHUB_USERNAME}/payflow-transaction-service:latest
docker tag payflowwallet2-notification-service:latest ${DOCKERHUB_USERNAME}/payflow-notification-service:latest

# Then push using the script
./push-to-dockerhub.sh yourusername
```

**What tagging does:**
- Creates a new reference to the same image
- Prepares it for Docker Hub (format: `username/image-name:tag`)
- Doesn't duplicate the image (just adds a new name)

### Step 5: Push Images to Docker Hub

**Push all images:**

```bash
# Replace 'yourusername' with your actual Docker Hub username
DOCKERHUB_USERNAME="yourusername"

# Push each image
docker push ${DOCKERHUB_USERNAME}/payflow-frontend:latest
docker push ${DOCKERHUB_USERNAME}/payflow-api-gateway:latest
docker push ${DOCKERHUB_USERNAME}/payflow-auth-service:latest
docker push ${DOCKERHUB_USERNAME}/payflow-wallet-service:latest
docker push ${DOCKERHUB_USERNAME}/payflow-transaction-service:latest
docker push ${DOCKERHUB_USERNAME}/payflow-notification-service:latest
```

**Or use the provided script:**
```bash
./push-to-dockerhub.sh yourusername
```

**Expected Output:**
```
🚀 Pushing PayFlow images to Docker Hub as: yourusername

📦 Tagging: payflow/api-gateway:latest -> yourusername/api-gateway:latest
⬆️  Pushing: yourusername/api-gateway:latest
✅ Successfully pushed: yourusername/api-gateway:latest
...
🎉 All images pushed to Docker Hub!
```

**This will take a few minutes** (first push is slower, subsequent pushes are faster due to layer caching).

### Step 6: Verify Images on Docker Hub

1. Go to https://hub.docker.com
2. Click on your username
3. You should see all 6 images:
   - `yourusername/payflow-frontend`
   - `yourusername/payflow-api-gateway`
   - `yourusername/payflow-auth-service`
   - `yourusername/payflow-wallet-service`
   - `yourusername/payflow-transaction-service`
   - `yourusername/payflow-notification-service`

### Step 7: Update Kubernetes Deployments to Use Docker Hub Images

**Now that images are on Docker Hub, update your Kubernetes deployment files:**

**For each deployment file** (`k8s/deployments/*.yaml`), update the image reference:

**Before (local image):**
```yaml
image: payflow/api-gateway:latest
imagePullPolicy: Never
```

**After (Docker Hub):**
```yaml
image: yourusername/payflow-api-gateway:latest
imagePullPolicy: IfNotPresent
```

**Or use a script to update all at once:**
```bash
# Replace 'yourusername' with your Docker Hub username
DOCKERHUB_USERNAME="yourusername"

# Update all deployment files
find k8s/deployments -name "*.yaml" -exec sed -i '' "s|image: payflow/|image: ${DOCKERHUB_USERNAME}/payflow-|g" {} \;
find k8s/deployments -name "*.yaml" -exec sed -i '' "s|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g" {} \;
```

**Why `IfNotPresent`?**
- Kubernetes will pull the image if it doesn't exist locally
- If the image exists (from a previous pull), it uses the local copy
- Faster than `Always` (which always pulls, even if local copy exists)

### Alternative: Use Local MicroK8s Registry (Advanced)

**If you prefer not to use Docker Hub**, you can use MicroK8s's local registry:

```bash
# Tag for local registry
docker tag payflowwallet2-frontend:latest localhost:32000/payflow-frontend:latest
# ... (repeat for all services)

# Push to local registry
docker push localhost:32000/payflow-frontend:latest
# ... (repeat for all services)

# In deployments, use:
image: localhost:32000/payflow-frontend:latest
imagePullPolicy: IfNotPresent
```

**When to use local registry:**
- You don't want to use Docker Hub
- You're working completely offline
- You want faster image pulls (no network)

**When to use Docker Hub:**
- You want to learn production workflows
- You're sharing images with others
- You're deploying to cloud (EKS/AKS/GKE)
- **Recommended for learning**

---

## Create Kubernetes Manifests

We'll create the following manifest files:
1. **Namespace** - Logical isolation
2. **ConfigMaps** - Configuration data
3. **Secrets** - Sensitive data
4. **PersistentVolumes** - Storage
5. **Deployments** - Application workloads
6. **Services** - Internal networking
7. **Ingress** - External access

### Directory Structure
```bash
mkdir -p k8s/{infrastructure,services,ingress}

# Structure:
# k8s/
# ├── infrastructure/
# │   ├── namespace.yaml
# │   ├── configmap.yaml
# │   ├── secrets.yaml
# │   ├── postgres.yaml
# │   ├── redis.yaml
# │   └── rabbitmq.yaml
# ├── services/
# │   ├── auth-service.yaml
# │   ├── wallet-service.yaml
# │   ├── transaction-service.yaml
# │   ├── notification-service.yaml
# │   ├── api-gateway.yaml
# │   └── frontend.yaml
# └── ingress/
#     └── ingress.yaml
```

---

## Deploy to MicroK8s

### Step 1: Deploy Infrastructure
```bash
# Create namespace (if not already created)
kubectl apply -f k8s/infrastructure/namespace.yaml

# Deploy ConfigMaps and Secrets
kubectl apply -f k8s/infrastructure/configmap.yaml
kubectl apply -f k8s/infrastructure/secrets.yaml

# Deploy databases and message queue
kubectl apply -f k8s/infrastructure/postgres.yaml
kubectl apply -f k8s/infrastructure/redis.yaml
kubectl apply -f k8s/infrastructure/rabbitmq.yaml

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s -n payflow
kubectl wait --for=condition=ready pod -l app=redis --timeout=120s -n payflow
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=120s -n payflow
```

### Step 2: Deploy Backend Services
```bash
# Deploy all backend services
kubectl apply -f k8s/services/auth-service.yaml
kubectl apply -f k8s/services/wallet-service.yaml
kubectl apply -f k8s/services/transaction-service.yaml
kubectl apply -f k8s/services/notification-service.yaml

# Wait for services to be ready
kubectl wait --for=condition=ready pod -l app=auth-service --timeout=120s -n payflow
kubectl wait --for=condition=ready pod -l app=wallet-service --timeout=120s -n payflow
kubectl wait --for=condition=ready pod -l app=transaction-service --timeout=120s -n payflow
kubectl wait --for=condition=ready pod -l app=notification-service --timeout=120s -n payflow
```

### Step 3: Deploy API Gateway
```bash
# Deploy API Gateway
kubectl apply -f k8s/services/api-gateway.yaml

# Wait for API Gateway
kubectl wait --for=condition=ready pod -l app=api-gateway --timeout=120s -n payflow
```

### Step 4: Deploy Frontend
```bash
# Deploy Frontend
kubectl apply -f k8s/services/frontend.yaml

# Wait for Frontend
kubectl wait --for=condition=ready pod -l app=frontend --timeout=120s -n payflow
```

### Step 5: Deploy Ingress
```bash
# Deploy Ingress for external access
kubectl apply -f k8s/ingress/ingress.yaml

# Verify Ingress
kubectl get ingress -n payflow
```

**Note**: For HTTPS setup with self-signed certificates (mimicking production), see [Step 20: Configure Ingress with HTTPS (Local Development)](#step-20-configure-ingress-with-https-local-development).

---

## Verify Deployment

### Check All Resources
```bash
# View all resources in payflow namespace
kubectl get all -n payflow

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# pod/postgres-xxxxx                        1/1     Running   0          5m
# pod/redis-xxxxx                           1/1     Running   0          5m
# pod/rabbitmq-xxxxx                        1/1     Running   0          5m
# pod/auth-service-xxxxx                    1/1     Running   0          3m
# pod/wallet-service-xxxxx                  1/1     Running   0          3m
# pod/transaction-service-xxxxx             1/1     Running   0          3m
# pod/notification-service-xxxxx            1/1     Running   0          3m
# pod/api-gateway-xxxxx                     1/1     Running   0          2m
# pod/frontend-xxxxx                        1/1     Running   0          1m
```

### Check Pods
```bash
# List all pods
kubectl get pods -n payflow

# Check pod details
kubectl describe pod <pod-name> -n payflow

# View pod logs
kubectl logs <pod-name> -n payflow

# Follow logs in real-time
kubectl logs -f <pod-name> -n payflow
```

### Check Services
```bash
# List all services
kubectl get services -n payflow

# Check service endpoints
kubectl get endpoints -n payflow

# Describe service
kubectl describe service api-gateway -n payflow
```

### Check ConfigMaps and Secrets
```bash
# List ConfigMaps
kubectl get configmaps -n payflow

# View ConfigMap
kubectl describe configmap payflow-config -n payflow

# List Secrets
kubectl get secrets -n payflow
```

### Check PersistentVolumes
```bash
# List PVCs
kubectl get pvc -n payflow

# Check storage
kubectl describe pvc postgres-pvc -n payflow
```

---

## Access Application

### Method 1: Port Forward (Development)
```bash
# Forward frontend port to localhost
kubectl port-forward service/frontend 8080:80 -n payflow

# Access application
open http://localhost:8080
```

### Method 2: NodePort (if configured)
```bash
# Get NodePort
kubectl get service frontend -n payflow

# Access via NodePort
# http://<node-ip>:<node-port>
```

### Method 3: Ingress (Production)
```bash
# Get Ingress details
kubectl get ingress -n payflow

# Add to /etc/hosts
echo "127.0.0.1 payflow.local" | sudo tee -a /etc/hosts

# Access application
open http://payflow.local
```

### Method 4: LoadBalancer IP (if available)
```bash
# Get external IP
kubectl get service frontend -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Access via IP
# http://<external-ip>
```

---

## Useful Commands

### Scaling
```bash
# Scale deployment
kubectl scale deployment wallet-service --replicas=3 -n payflow

# Autoscale based on CPU
kubectl autoscale deployment wallet-service --min=2 --max=5 --cpu-percent=80 -n payflow

# View autoscalers
kubectl get hpa -n payflow
```

### Updates
```bash
# Update image
kubectl set image deployment/wallet-service wallet-service=localhost:32000/payflow-wallet-service:v2 -n payflow

# Rollout status
kubectl rollout status deployment/wallet-service -n payflow

# Rollout history
kubectl rollout history deployment/wallet-service -n payflow

# Rollback
kubectl rollout undo deployment/wallet-service -n payflow
```

### Debugging
```bash
# Execute command in pod
kubectl exec -it <pod-name> -n payflow -- sh

# Check environment variables
kubectl exec <pod-name> -n payflow -- env

# Copy files from pod
kubectl cp <pod-name>:/path/to/file ./local-file -n payflow

# Check resource usage
kubectl top pods -n payflow
kubectl top nodes
```

### Logs
```bash
# View logs
kubectl logs <pod-name> -n payflow

# Logs from previous container (if crashed)
kubectl logs <pod-name> -n payflow --previous

# Logs from specific container in pod
kubectl logs <pod-name> -c <container-name> -n payflow

# Stream logs
kubectl logs -f <pod-name> -n payflow

# Logs from all pods with label
kubectl logs -l app=wallet-service -n payflow
```

---

## Troubleshooting

### Issue: Pods Not Starting
```bash
# Check pod status
kubectl get pods -n payflow

# Describe pod for events
kubectl describe pod <pod-name> -n payflow

# Common causes:
# 1. Image pull errors
# 2. Insufficient resources
# 3. ConfigMap/Secret missing
# 4. Health check failures
```

### Issue: ImagePullBackOff
```bash
# Check image name
kubectl describe pod <pod-name> -n payflow | grep Image

# Verify image exists in registry
curl http://localhost:32000/v2/payflow-wallet-service/tags/list

# Fix: Rebuild and push image
docker-compose build wallet-service
docker tag payflowwallet2-wallet-service:latest localhost:32000/payflow-wallet-service:latest
docker push localhost:32000/payflow-wallet-service:latest

# Restart deployment
kubectl rollout restart deployment/wallet-service -n payflow
```

### Issue: CrashLoopBackOff
```bash
# Check logs
kubectl logs <pod-name> -n payflow

# Check previous logs
kubectl logs <pod-name> -n payflow --previous

# Common causes:
# 1. Application error
# 2. Missing environment variables
# 3. Cannot connect to database
# 4. Port already in use
```

### Issue: Service Not Reachable
```bash
# Check service
kubectl get service <service-name> -n payflow

# Check endpoints
kubectl get endpoints <service-name> -n payflow

# If no endpoints: pods not matching selector
kubectl get pods -n payflow --show-labels

# Test from another pod
kubectl run test --image=busybox -it --rm -n payflow -- wget -qO- http://wallet-service:3001/health
```

### Issue: Database Connection Failed
```bash
# Check if postgres is running
kubectl get pods -l app=postgres -n payflow

# Check postgres logs
kubectl logs <postgres-pod> -n payflow

# Test connection from app pod
kubectl exec -it <app-pod> -n payflow -- sh
# Inside pod:
nc -zv postgres 5432
```

### Issue: Out of Resources
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n payflow

# Describe node
kubectl describe node <node-name>

# Solution: Reduce resource requests or add nodes
```

---

## Cleanup

### Delete PayFlow Application
```bash
# Delete all resources in namespace
kubectl delete namespace payflow

# Or delete specific resources
kubectl delete -f k8s/services/ -n payflow
kubectl delete -f k8s/infrastructure/ -n payflow
kubectl delete -f k8s/ingress/ -n payflow
```

### Stop MicroK8s
```bash
# Stop MicroK8s
microk8s stop

# Reset MicroK8s (⚠️ deletes everything)
microk8s reset
```

---

## Next Steps

1. ✅ Application running in MicroK8s
2. ✅ Horizontal Pod Autoscaling (HPA) configured
3. 🔄 **Multi-Node Cluster Setup**: See [Cluster Autoscaling Guide](cluster-autoscaling.md) for setting up a multi-node MicroK8s cluster
4. 🔄 Set up CI/CD pipeline
5. 🔄 Configure monitoring (Prometheus/Grafana)
6. 🔄 Set up logging (ELK/Loki)
7. 🔄 Implement GitOps (ArgoCD/Flux)
8. 🔄 Add network policies
9. 🔄 Configure backups
10. 🔄 **Production Deployment**: When ready for production, see [Cluster Autoscaling Guide](cluster-autoscaling.md) for cloud autoscaling options (EKS/AKS/GKE)

---

## Actual Deployment Process (Step-by-Step)

This section documents the **actual process** we followed to deploy PayFlow to MicroK8s, including all commands, issues encountered, and solutions.

### Step 1: MicroK8s Setup and Configuration

#### 1.1 Install MicroK8s (macOS)
```bash
# Install MicroK8s via Homebrew
brew install ubuntu/microk8s/microk8s
microk8s install

# Note: On macOS, MicroK8s runs in a Multipass VM
# No need for usermod (that's Linux-specific)
```

#### 1.2 Enable Required Add-ons
```bash
# Enable essential add-ons
microk8s enable dns
microk8s enable storage
microk8s enable registry
microk8s enable ingress
microk8s enable metrics-server

# Verify status
microk8s status
```

#### 1.3 Configure kubectl to Access MicroK8s
```bash
# Export MicroK8s config to kubeconfig
microk8s config > ~/.kube/microk8s-config

# Set KUBECONFIG environment variable
export KUBECONFIG=~/.kube/microk8s-config

# Verify connection
kubectl get nodes
kubectl cluster-info
```

**Note**: If you get connection errors, run the above commands again. The MicroK8s VM needs to be fully started.

#### 1.4 Clean Up Previous Resources
```bash
# Delete existing PayFlow namespace (if any)
kubectl delete namespace payflow

# Wait for namespace to fully terminate
kubectl get namespace payflow

# Delete ArgoCD namespace (if needed)
kubectl delete namespace argocd

# If namespace is stuck in "Terminating", remove finalizers
kubectl patch application.argoproj.io payflow -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Step 2: Create Namespace

```bash
# Create fresh namespace
kubectl apply -f k8s/namespace.yaml

# Verify
kubectl get namespace payflow
```

**File**: `k8s/namespace.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: payflow
```

### Step 3: Create ConfigMaps and Secrets

#### 3.1 Create ConfigMap
```bash
kubectl apply -f k8s/configmaps/app-config.yaml
```

**File**: `k8s/configmaps/app-config.yaml`
- Contains: `DB_HOST`, `DB_PORT`, `DB_NAME`, `REDIS_URL`, `RABBITMQ_URL`, service URLs
- Non-sensitive configuration data

#### 3.2 Create Secrets
```bash
kubectl apply -f k8s/secrets/db-secrets.yaml
```

**File**: `k8s/secrets/db-secrets.yaml`
- Contains: `DB_USER`, `DB_PASSWORD`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `JWT_SECRET`
- Sensitive data (encrypted at rest)

**Verify**:
```bash
kubectl get configmaps -n payflow
kubectl get secrets -n payflow
```

### Step 4: Deploy Infrastructure Services

#### 4.1 Deploy PostgreSQL (StatefulSet)

**Why StatefulSet?**
- Provides stable network identity (`postgres-0.postgres.payflow.svc.cluster.local`)
- Automatic PVC creation per pod via `volumeClaimTemplates`
- Ordered deployment and termination
- Perfect for databases

```bash
kubectl apply -f k8s/infrastructure/postgres.yaml
```

**Key Components**:
- **Service**: Headless service (`clusterIP: None`) for stable DNS
- **StatefulSet**: Manages PostgreSQL pod
- **volumeClaimTemplates**: Automatically creates PVC `postgres-storage-postgres-0` (10Gi)
- **volumeMounts**: Mounts PVC at `/var/lib/postgresql/data`

**Understanding Volume Claims**:
```yaml
# volumeClaimTemplates - Requests storage from Kubernetes
volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi  # Kubernetes provisions 10GB

# volumeMounts - Mounts the storage into container
volumeMounts:
  - name: postgres-storage
    mountPath: /var/lib/postgresql/data  # Container sees storage here
```

**Verify PostgreSQL**:
```bash
# Check pod status
kubectl get pods -n payflow -l app=postgres

# Check PVC
kubectl get pvc -n payflow

# Check logs
kubectl logs -n payflow postgres-0 --tail=5

# Expected output:
# database system is ready to accept connections
```

#### 4.2 Deploy Redis
```bash
kubectl apply -f k8s/infrastructure/redis.yaml
```

**Verify**:
```bash
kubectl get pods -n payflow -l app=redis
kubectl logs -n payflow -l app=redis --tail=5
```

#### 4.3 Deploy RabbitMQ
```bash
kubectl apply -f k8s/infrastructure/rabbitmq.yaml
```

**Verify**:
```bash
kubectl get pods -n payflow -l app=rabbitmq
kubectl get services -n payflow rabbitmq
```

**Check All Infrastructure**:
```bash
kubectl get pods -n payflow
kubectl get services -n payflow
```

### Step 4.4: Deploy Database Migration Job

#### 4.4.1 Overview

**What it does**: Creates database tables (users, wallets, transactions) and indexes on first deployment.

**Why you need it**: 
- Services expect database tables to exist before they start
- Without it, services will crash with "table does not exist" errors
- Ensures database schema is consistent across deployments
- Creates performance indexes for faster queries

**What happens without it**:
- ❌ Auth service fails: "relation 'users' does not exist"
- ❌ Wallet service fails: "relation 'wallets' does not exist"
- ❌ Transaction service fails: "relation 'transactions' does not exist"
- ❌ Application completely broken - no services can start

**How it works**:
1. Job waits for PostgreSQL to be ready (using `pg_isready`)
2. Creates tables with `CREATE TABLE IF NOT EXISTS` (safe to run multiple times)
3. Creates indexes for performance (email lookups, wallet queries, transaction searches)
4. Job completes and doesn't restart (one-time execution)

#### 4.4.2 Deploy Migration Job

**File**: `k8s/jobs/db-migration-job.yaml`

**Deploy**:
```bash
# Deploy migration job
kubectl apply -f k8s/jobs/db-migration-job.yaml

# Wait for job to complete
kubectl wait --for=condition=complete job/db-migration-job -n payflow --timeout=120s
```

**Verify**:
```bash
# Check job status
kubectl get jobs -n payflow db-migration-job

# View job logs
kubectl logs -n payflow -l job-name=db-migration-job

# Expected output:
# Waiting for PostgreSQL to be ready...
# PostgreSQL is ready! Running migrations...
# ✅ Database migrations completed successfully!
```

**Expected Status**:
```
NAME                COMPLETIONS   DURATION   AGE
db-migration-job    1/1           15s        2m
```

**Verify Tables Created**:
```bash
# Connect to PostgreSQL and verify tables
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "\dt"

# Expected output:
#              List of relations
#  Schema |      Name       | Type  |  Owner
# --------+-----------------+-------+--------
#  public | transactions    | table | payflow
#  public | users           | table | payflow
#  public | wallets         | table | payflow
```

#### 4.4.3 Understanding the Migration Job

**Job vs CronJob**:
- **Job**: Runs once and completes (perfect for migrations)
- **CronJob**: Runs on a schedule (for recurring tasks)

**Why `restartPolicy: OnFailure`**:
- If migration fails, Kubernetes will retry
- Once successful, job completes and doesn't restart
- Prevents infinite retries on permanent failures

**Safe to Re-run**:
- Uses `CREATE TABLE IF NOT EXISTS` - won't fail if tables already exist
- Uses `CREATE INDEX IF NOT EXISTS` - won't fail if indexes already exist
- Can safely re-run the job without breaking existing data

### Step 5: Build and Import Docker Images

**Important**: MicroK8s runs in a Multipass VM on macOS. We need to build images inside the VM or import them.

#### 5.1 Method 1: Build Inside MicroK8s VM (Recommended)

**macOS (Multipass VM)**:
```bash
# Build image inside MicroK8s VM
multipass exec microk8s-vm -- sudo docker build \
  -t payflow/auth-service:latest \
  -f services/auth-service/Dockerfile \
  services/auth-service

# Note: This requires Docker installed inside the VM
# If Docker is not installed:
multipass exec microk8s-vm -- sudo apt-get update
multipass exec microk8s-vm -- sudo apt-get install -y docker.io
```

**Windows (Multipass VM)**:
```powershell
# Build image inside MicroK8s VM
multipass exec microk8s-vm -- sudo docker build `
  -t payflow/auth-service:latest `
  -f services/auth-service/Dockerfile `
  services/auth-service

# If Docker is not installed in VM:
multipass exec microk8s-vm -- sudo apt-get update
multipass exec microk8s-vm -- sudo apt-get install -y docker.io
```

**Windows (WSL2)**:
```bash
# Inside WSL2, build directly (no VM needed)
docker build -t payflow/auth-service:latest \
  -f services/auth-service/Dockerfile \
  services/auth-service

# Then import to MicroK8s (see Method 2)
```

**Linux (Native)**:
```bash
# Build directly (no VM)
docker build -t payflow/auth-service:latest \
  -f services/auth-service/Dockerfile \
  services/auth-service

# Then import to MicroK8s (see Method 2)
```

#### 5.2 Method 2: Build on Host and Import

**macOS (Multipass VM)**:
```bash
# Step 1: Build image on host machine
cd "/Users/mac/Desktop/Coaching/PayFlow Wallet 2"
docker build -t payflow/auth-service:latest \
  -f services/auth-service/Dockerfile \
  services/auth-service

# Step 2: Save image to tar file
docker save payflow/auth-service:latest -o /tmp/auth-service.tar

# Step 3: Transfer to MicroK8s VM
multipass transfer /tmp/auth-service.tar microk8s-vm:/tmp/auth-service.tar

# Step 4: Import into MicroK8s containerd
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/auth-service.tar

# Step 5: Clean up
multipass exec microk8s-vm -- sudo rm /tmp/auth-service.tar
rm /tmp/auth-service.tar

# Step 6: Verify image is available
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep auth-service
```

**Windows (Multipass VM)**:
```powershell
# Step 1: Build image on host machine (Docker Desktop)
cd "C:\Users\<YourUser>\Desktop\Coaching\PayFlow Wallet 2"
docker build -t payflow/auth-service:latest `
  -f services/auth-service/Dockerfile `
  services/auth-service

# Step 2: Save image to tar file
docker save payflow/auth-service:latest -o $env:TEMP\auth-service.tar

# Step 3: Transfer to MicroK8s VM
multipass transfer $env:TEMP\auth-service.tar microk8s-vm:/tmp/auth-service.tar

# Step 4: Import into MicroK8s containerd
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/auth-service.tar

# Step 5: Clean up
multipass exec microk8s-vm -- sudo rm /tmp/auth-service.tar
Remove-Item $env:TEMP\auth-service.tar

# Step 6: Verify
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep auth-service
```

**Windows (WSL2)**:
```bash
# Step 1: Build in WSL2 (or use Docker Desktop from Windows)
cd "/mnt/c/Users/<YourUser>/Desktop/Coaching/PayFlow Wallet 2"
docker build -t payflow/auth-service:latest \
  -f services/auth-service/Dockerfile \
  services/auth-service

# Step 2: Save image
docker save payflow/auth-service:latest -o /tmp/auth-service.tar

# Step 3: Import directly (no VM transfer needed)
sudo microk8s ctr images import /tmp/auth-service.tar

# Step 4: Clean up
rm /tmp/auth-service.tar

# Step 5: Verify
sudo microk8s ctr images ls | grep auth-service
```

**Linux (Native)**:
```bash
# Step 1: Build image
cd "/path/to/PayFlow Wallet 2"
docker build -t payflow/auth-service:latest \
  -f services/auth-service/Dockerfile \
  services/auth-service

# Step 2: Save image
docker save payflow/auth-service:latest -o /tmp/auth-service.tar

# Step 3: Import directly
sudo microk8s ctr images import /tmp/auth-service.tar

# Step 4: Clean up
rm /tmp/auth-service.tar

# Step 5: Verify
sudo microk8s ctr images ls | grep auth-service
```

**Expected Output**:
```
docker.io/payflow/auth-service:latest    application/vnd.oci.image.index.v1+json    sha256:...    45.1 MiB
```

**Why `imagePullPolicy: Never`?**
- When using `imagePullPolicy: Never`, Kubernetes uses the image directly from containerd
- No registry pull needed
- Image must be imported into MicroK8s containerd first

### Step 6: Deploy Backend Services

#### 6.1 Deploy Auth Service

**Create Deployment File**: `k8s/deployments/auth-service.yaml`

**Key Configuration**:
- Uses ConfigMap for non-sensitive config (`DB_HOST`, `DB_PORT`, `REDIS_URL`)
- Uses Secret for sensitive data (`DB_USER`, `DB_PASSWORD`, `JWT_SECRET`)
- Environment variables from ConfigMap/Secret:
  ```yaml
  env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DB_HOST
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secrets
          key: DB_PASSWORD
  ```

**Deploy**:
```bash
kubectl apply -f k8s/deployments/auth-service.yaml
```

**Verify**:
```bash
# Check pods
kubectl get pods -n payflow -l app=auth-service

# Check service
kubectl get service -n payflow auth-service

# Check logs
kubectl logs -n payflow -l app=auth-service --tail=10

# Expected: Health check requests (200 status)
```

**Service Configuration**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  namespace: payflow
spec:
  selector:
    app: auth-service
  ports:
  - protocol: TCP
    port: 3004
    targetPort: 3004
  type: ClusterIP  # Internal service
```

**Deployment Configuration**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  namespace: payflow
spec:
  replicas: 2  # High availability
  selector:
    matchLabels:
      app: auth-service
  template:
    spec:
      containers:
      - name: auth-service
        image: payflow/auth-service:latest
        imagePullPolicy: Never  # Use local image
        env:
          # Database config from ConfigMap/Secret
          # Redis config from ConfigMap
          # JWT config from Secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3004
        readinessProbe:
          httpGet:
            path: /health
            port: 3004
```

#### 6.2 Deploy Wallet Service

**Build and Import Image**:
```bash
# Build wallet-service image (context is services/ because it needs shared folder)
docker build -t payflow/wallet-service:latest \
  -f services/wallet-service/Dockerfile \
  services/

# Save and import
docker save payflow/wallet-service:latest -o /tmp/wallet-service.tar
multipass transfer /tmp/wallet-service.tar microk8s-vm:/tmp/wallet-service.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/wallet-service.tar
multipass exec microk8s-vm -- sudo rm /tmp/wallet-service.tar
rm /tmp/wallet-service.tar

# Verify
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep wallet-service
```

**Create Deployment File**: `k8s/deployments/wallet-service.yaml`

**Key Configuration**:
- Needs: PostgreSQL, Redis
- Uses ConfigMap for `DB_HOST`, `DB_PORT`, `DB_NAME`, `REDIS_URL`
- Uses Secret for `DB_USER`, `DB_PASSWORD`
- Logs volume: `emptyDir` mounted at `/app/logs`
- 2 replicas for high availability

**Deploy**:
```bash
kubectl apply -f k8s/deployments/wallet-service.yaml
```

**Verify**:
```bash
kubectl get pods -n payflow -l app=wallet-service
kubectl get service -n payflow wallet-service
kubectl logs -n payflow -l app=wallet-service --tail=5
```

**Expected Output**:
```
NAME                              READY   STATUS    RESTARTS   AGE
wallet-service-xxx-xxx            1/1     Running   0          16s
wallet-service-xxx-xxx            1/1     Running   0          16s
```

#### 6.3 Deploy Notification Service

**Build and Import Image**:
```bash
# Build notification-service image
docker build -t payflow/notification-service:latest \
  -f services/notification-service/Dockerfile \
  services/

# Save and import
docker save payflow/notification-service:latest -o /tmp/notification-service.tar
multipass transfer /tmp/notification-service.tar microk8s-vm:/tmp/notification-service.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/notification-service.tar
multipass exec microk8s-vm -- sudo rm /tmp/notification-service.tar
rm /tmp/notification-service.tar

# Verify
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep notification-service
```

**Create Deployment File**: `k8s/deployments/notification-service.yaml`

**Key Configuration**:
- Needs: PostgreSQL, RabbitMQ
- Uses ConfigMap for `DB_HOST`, `DB_PORT`, `DB_NAME`
- Uses Secret for `DB_USER`, `DB_PASSWORD`
- `RABBITMQ_URL`: Constructed with credentials (`amqp://payflow:payflow123@rabbitmq:5672`)
- 2 replicas for high availability
- Health checks on port 3003

**Deploy**:
```bash
kubectl apply -f k8s/deployments/notification-service.yaml
```

**Verify**:
```bash
kubectl get pods -n payflow -l app=notification-service
kubectl get service -n payflow notification-service
kubectl logs -n payflow -l app=notification-service --tail=5
```

**Expected Output**:
```
NAME                                    READY   STATUS    RESTARTS   AGE
notification-service-xxx-xxx            1/1     Running   0          19s
notification-service-xxx-xxx            1/1     Running   0          20s
```

#### 6.4 Deploy Transaction Service

**Build and Import Image**:
```bash
# Build transaction-service image
docker build -t payflow/transaction-service:latest \
  -f services/transaction-service/Dockerfile \
  services/

# Save and import
docker save payflow/transaction-service:latest -o /tmp/transaction-service.tar
multipass transfer /tmp/transaction-service.tar microk8s-vm:/tmp/transaction-service.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/transaction-service.tar
multipass exec microk8s-vm -- sudo rm /tmp/transaction-service.tar
rm /tmp/transaction-service.tar

# Verify
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep transaction-service
```

**Create Deployment File**: `k8s/deployments/transaction-service.yaml`

**Key Configuration**:
- Needs: PostgreSQL, Redis, RabbitMQ, Wallet Service
- Uses ConfigMap for `DB_HOST`, `DB_PORT`, `DB_NAME`, `REDIS_URL`, `WALLET_SERVICE_URL`
- Uses Secret for `DB_USER`, `DB_PASSWORD`
- `RABBITMQ_URL`: Constructed with credentials
- 3 replicas initially (scaled by HPA)
- Logs volume: `emptyDir` mounted at `/app/logs`
- Health checks on port 3002

**Horizontal Pod Autoscaler (HPA)**:
- Included in the same YAML file
- Scales from 2 to 10 replicas based on CPU utilization (70% threshold)
- Automatically adjusts based on load

**Deploy**:
```bash
kubectl apply -f k8s/deployments/transaction-service.yaml
```

**Verify**:
```bash
# Check pods
kubectl get pods -n payflow -l app=transaction-service

# Check service
kubectl get service -n payflow transaction-service

# Check HPA
kubectl get hpa -n payflow transaction-service-hpa

# Check logs
kubectl logs -n payflow -l app=transaction-service --tail=5
```

**Expected Output**:
```
NAME                                    READY   STATUS    RESTARTS   AGE
transaction-service-xxx-xxx             1/1     Running   0          19s
transaction-service-xxx-xxx             1/1     Running   0          19s
transaction-service-xxx-xxx             1/1     Running   0          19s

NAME                      REFERENCE                        TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
transaction-service-hpa   Deployment/transaction-service   cpu: <unknown>/70%   2         10        3          19s
```

**Note**: HPA shows `<unknown>` CPU initially - this is normal. It will show actual metrics once the metrics-server collects data.

### Step 7: Deploy Frontend

#### 7.1 Build Frontend Image

**Frontend API Configuration**: The frontend is configured to work in all environments automatically. See [Frontend API Configuration Guide](frontend-api-configuration.md) for details.

```bash
# Build on host
docker build -t payflow/frontend:latest \
  -f services/frontend/Dockerfile \
  services/frontend

# Save and import
docker save payflow/frontend:latest -o /tmp/frontend.tar
multipass transfer /tmp/frontend.tar microk8s-vm:/tmp/frontend.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/frontend.tar
multipass exec microk8s-vm -- sudo rm /tmp/frontend.tar
rm /tmp/frontend.tar
```

#### 7.2 Deploy Frontend

```bash
kubectl apply -f k8s/deployments/frontend.yaml
```

**Note**: Frontend may fail initially if API Gateway is not deployed yet (nginx tries to resolve `api-gateway` at startup).

#### 7.3 Deploy API Gateway

**Build and Import Image**:
```bash
# Build api-gateway image (context is services/ because it needs shared folder)
docker build -t payflow/api-gateway:latest \
  -f services/api-gateway/Dockerfile \
  services/

# Save and import
docker save payflow/api-gateway:latest -o /tmp/api-gateway.tar
multipass transfer /tmp/api-gateway.tar microk8s-vm:/tmp/api-gateway.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/api-gateway.tar
multipass exec microk8s-vm -- sudo rm /tmp/api-gateway.tar
rm /tmp/api-gateway.tar

# Verify
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep api-gateway
```

**Create Deployment File**: `k8s/deployments/api-gateway.yaml`

**Key Configuration**:
- Needs: Auth, Wallet, Transaction services (all backend services)
- Uses ConfigMap for service URLs (`AUTH_SERVICE_URL`, `WALLET_SERVICE_URL`, etc.)
- LoadBalancer service type (external access)
- 2 replicas for high availability
- Health checks on port 3000

**Deploy**:
```bash
kubectl apply -f k8s/deployments/api-gateway.yaml
```

**Verify**:
```bash
kubectl get pods -n payflow -l app=api-gateway
kubectl get service -n payflow api-gateway
kubectl logs -n payflow -l app=api-gateway --tail=5
```

**Expected Output**:
```
NAME                           READY   STATUS    RESTARTS   AGE
api-gateway-xxx-xxx            1/1     Running   0          16s
api-gateway-xxx-xxx            1/1     Running   0          16s

NAME          TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)        AGE
api-gateway   LoadBalancer   10.152.183.130   10.1.254.100   80:30842/TCP   17s
```

**Note**: LoadBalancer gets an external IP (10.1.254.100) if MetalLB is enabled in MicroK8s.

#### 7.4 Restart Frontend After API Gateway

Once API Gateway is deployed, restart the frontend so nginx can resolve it:

```bash
kubectl delete pod -n payflow -l app=frontend
kubectl get pods -n payflow -l app=frontend
```

### Step 8: Set Up Port Forwarding for Access

Since services are running inside Kubernetes, we need port-forwarding to access them from the host machine.

#### 8.1 Port-Forward API Gateway

```bash
# Forward API Gateway to localhost:3000
kubectl port-forward service/api-gateway 3000:80 -n payflow &

# Verify it's working
curl http://localhost:3000/health
```

**Expected Output**:
```json
{"status":"healthy","timestamp":"2025-12-25T12:13:20.867Z","service":"api-gateway","version":"1.0.0"}
```

#### 8.2 Port-Forward Frontend

```bash
# Forward Frontend to localhost:8080
kubectl port-forward service/frontend 8080:80 -n payflow &

# Verify it's working
curl http://localhost:8080/health
```

**Expected Output**:
```
healthy
```

**Note**: Both port-forwards run in the background. To keep them running:
- Keep the terminal open, or
- Run them in separate terminals

**To check if port-forwards are running**:
```bash
ps aux | grep "kubectl port-forward" | grep -v grep
```

#### 8.3 Advanced Port-Forward Management (Production-Ready)

For production-like scenarios or when you need persistent, manageable port-forwards, use this approach:

```bash
# Start port-forwards with process management
nohup kubectl port-forward service/frontend 8080:80 -n payflow > /tmp/frontend-portforward.log 2>&1 &
echo $! > /tmp/frontend-portforward.pid
sleep 2
nohup kubectl port-forward service/api-gateway 3000:80 -n payflow > /tmp/api-portforward.log 2>&1 &
echo $! > /tmp/api-portforward.pid
sleep 3

# Verify they're running
ps -p $(cat /tmp/frontend-portforward.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Frontend port-forward: RUNNING (PID: $(cat /tmp/frontend-portforward.pid))" || echo "❌ Frontend port-forward: NOT RUNNING"
ps -p $(cat /tmp/api-portforward.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ API Gateway port-forward: RUNNING (PID: $(cat /tmp/api-portforward.pid))" || echo "❌ API Gateway port-forward: NOT RUNNING"
```

**Why This Approach?**

1. **`nohup`**: 
   - Runs commands that survive terminal closure
   - Prevents processes from being killed when you close the terminal
   - Essential for long-running port-forwards

2. **`> /tmp/frontend-portforward.log 2>&1`**:
   - Redirects stdout (`>`) to a log file
   - `2>&1` redirects stderr to the same place as stdout
   - Allows you to check logs if something goes wrong
   - Example: `tail -f /tmp/frontend-portforward.log`

3. **`&`**:
   - Runs the command in the background
   - Returns control to the terminal immediately
   - Allows running multiple commands sequentially

4. **`echo $! > /tmp/frontend-portforward.pid`**:
   - `$!` is the PID (Process ID) of the last background command
   - Saves the PID to a file for later management
   - Enables you to stop the process: `kill $(cat /tmp/frontend-portforward.pid)`

5. **`sleep 2` / `sleep 3`**:
   - Waits between commands to ensure processes start properly
   - Prevents race conditions
   - Gives time for port-forward to establish connection

6. **`ps -p $(cat /tmp/frontend-portforward.pid)`**:
   - Checks if the process with saved PID is still running
   - `ps -p <PID>` shows process info if it exists
   - `> /dev/null 2>&1` suppresses output (we only care about exit code)
   - Used in conditional to show status

**Benefits of This Approach**:

- ✅ **Persistent**: Survives terminal closure
- ✅ **Manageable**: Can stop/restart using saved PIDs
- ✅ **Debuggable**: Logs available in `/tmp/*.log` files
- ✅ **Verifiable**: Can check if processes are running
- ✅ **Production-like**: Similar to how you'd manage services in production

**Managing Port-Forwards**:

```bash
# Check status
ps -p $(cat /tmp/frontend-portforward.pid 2>/dev/null) > /dev/null 2>&1 && echo "Running" || echo "Stopped"
ps -p $(cat /tmp/api-portforward.pid 2>/dev/null) > /dev/null 2>&1 && echo "Running" || echo "Stopped"

# View logs
tail -f /tmp/frontend-portforward.log
tail -f /tmp/api-portforward.log

# Stop port-forwards
kill $(cat /tmp/frontend-portforward.pid 2>/dev/null)
kill $(cat /tmp/api-portforward.pid 2>/dev/null)

# Restart port-forwards
# (Run the start command again)
```

### Step 9: Error Handling Improvements

During deployment, we encountered issues with error messages. Here are the improvements made:

#### 9.1 Auth-Service: Improved Validation Error Messages

**Issue**: Auth-service was returning generic "Invalid value" messages for password validation.

**Fix**: Updated validation to provide specific error messages:

```javascript
body('password')
  .isLength({ min: 8 }).withMessage('Password must be at least 8 characters long')
  .matches(/^(?=.*[a-z])/).withMessage('Password must contain at least one lowercase letter')
  .matches(/^(?=.*[A-Z])/).withMessage('Password must contain at least one uppercase letter')
  .matches(/^(?=.*\d)/).withMessage('Password must contain at least one number')
```

**Result**: Users now see specific password requirements instead of generic errors.

#### 9.2 Frontend: Better Error Display

**Issue**: Frontend was showing "HTTP 400" instead of validation error details.

**Fix**: Updated error handling to parse and display validation errors:

```javascript
if (error.errors && Array.isArray(error.errors)) {
  // Group password errors together
  const passwordErrors = error.errors
    .filter(e => e.path === 'password')
    .map(e => e.msg);
  
  if (passwordErrors.length > 0) {
    throw new Error(`Password requirements: ${passwordErrors.join(', ')}`);
  }
  // ... handle other field errors
}
```

**Result**: Users see clear error messages like:
- "Password requirements: Password must be at least 8 characters long, Password must contain at least one uppercase letter, Password must contain at least one number"

#### 9.3 Rebuild and Redeploy After Error Handling Fixes

After making error handling improvements:

```bash
# Rebuild auth-service
docker build -t payflow/auth-service:latest \
  -f services/auth-service/Dockerfile \
  services/auth-service

# Rebuild frontend
docker build -t payflow/frontend:latest \
  -f services/frontend/Dockerfile \
  services/frontend

# Import both images
docker save payflow/auth-service:latest -o /tmp/auth-service.tar
docker save payflow/frontend:latest -o /tmp/frontend.tar
multipass transfer /tmp/auth-service.tar microk8s-vm:/tmp/auth-service.tar
multipass transfer /tmp/frontend.tar microk8s-vm:/tmp/frontend.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/auth-service.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/frontend.tar
multipass exec microk8s-vm -- sudo rm /tmp/auth-service.tar /tmp/frontend.tar
rm /tmp/auth-service.tar /tmp/frontend.tar

# Restart pods
kubectl delete pod -n payflow -l app=auth-service
kubectl delete pod -n payflow -l app=frontend
```

### Step 10: Verify Complete Deployment

```bash
# Check all pods
kubectl get pods -n payflow

# Check all services
kubectl get services -n payflow

# Check PVCs
kubectl get pvc -n payflow

# Check ConfigMaps and Secrets
kubectl get configmaps -n payflow
kubectl get secrets -n payflow
```

**Expected Status** (After All Services Deployed):
```
NAME                                    READY   STATUS    RESTARTS   AGE
api-gateway-xxx-xxx                     1/1     Running   0          79s
api-gateway-xxx-xxx                     1/1     Running   0          79s
auth-service-xxx-xxx                    1/1     Running   0          87m
auth-service-xxx-xxx                    1/1     Running   0          87m
frontend-xxx-xxx                        1/1     Running   0          19s
notification-service-xxx-xxx            1/1     Running   0          10m
notification-service-xxx-xxx            1/1     Running   0          10m
postgres-0                              1/1     Running   0          116m
rabbitmq-xxx-xxx                        1/1     Running   0          103m
redis-xxx-xxx                           1/1     Running   0          103m
transaction-service-xxx-xxx             1/1     Running   0          10m
transaction-service-xxx-xxx             1/1     Running   0          10m
transaction-service-xxx-xxx             1/1     Running   0          10m
wallet-service-xxx-xxx                  1/1     Running   0          27m
wallet-service-xxx-xxx                  1/1     Running   0          27m
```

**All Services Running**: ✅ 15 pods total, all healthy

### Step 11: Accessing the Application

#### 11.1 Port Forward Setup (Required)

**Both port-forwards must be running for the application to work:**

**macOS / Linux**:
```bash
# Terminal 1: Forward API Gateway (required for frontend to make API calls)
kubectl port-forward service/api-gateway 3000:80 -n payflow

# Terminal 2: Forward Frontend (to access the web UI)
kubectl port-forward service/frontend 8080:80 -n payflow
```

**Or run both in background**:
```bash
# API Gateway
kubectl port-forward service/api-gateway 3000:80 -n payflow &

# Frontend
kubectl port-forward service/frontend 8080:80 -n payflow &
```

**Windows (PowerShell)**:
```powershell
# Terminal 1: API Gateway
kubectl port-forward service/api-gateway 3000:80 -n payflow

# Terminal 2: Frontend
kubectl port-forward service/frontend 8080:80 -n payflow
```

**Windows (WSL2)**:
```bash
# Terminal 1: API Gateway
kubectl port-forward service/api-gateway 3000:80 -n payflow

# Terminal 2: Frontend
kubectl port-forward service/frontend 8080:80 -n payflow
```

#### 11.2 Access the Application

Once both port-forwards are running:

1. **Open browser**: `http://localhost:8080`
2. **Register a new account**:
   - Full Name: Your name
   - Email: your@email.com
   - Password: Must meet requirements (see below)
3. **Login** and start using PayFlow!

**Password Requirements**:
- At least 8 characters
- At least one lowercase letter (a-z)
- At least one uppercase letter (A-Z)
- At least one number (0-9)

**Example valid passwords**: `Test123!`, `Password1`, `MyPass123`

#### 11.3 Verify Port-Forwards Are Running

```bash
# Check if port-forwards are active
ps aux | grep "kubectl port-forward" | grep -v grep

# Test API Gateway
curl http://localhost:3000/health

# Test Frontend
curl http://localhost:8080/health
```

**Expected Output**:
```
# Port-forwards running:
mac  55935  ... kubectl port-forward service/api-gateway 3000:80 -n payflow
mac  61737  ... kubectl port-forward service/frontend 8080:80 -n payflow

# API Gateway health:
{"status":"healthy","timestamp":"...","service":"api-gateway","version":"1.0.0"}

# Frontend health:
healthy
```

### Step 12: Troubleshooting Common Issues

#### Issue 1: "Failed to fetch" Error

**Symptom**: Frontend shows "Failed to fetch" when trying to register/login.

**Cause**: API Gateway port-forward is not running.

**Fix**:
```bash
# Start API Gateway port-forward
kubectl port-forward service/api-gateway 3000:80 -n payflow &

# Verify it's working
curl http://localhost:3000/health
```

#### Issue 2: HTTP 400 with Generic Error Message

**Symptom**: Registration fails with "HTTP 400" but no specific error details.

**Cause**: Error handling not displaying validation errors properly.

**Fix**: Already implemented in auth-service and frontend:
- Auth-service now returns specific error messages
- Frontend displays password requirements clearly

**Example Error Messages**:
- "Password requirements: Password must be at least 8 characters long, Password must contain at least one uppercase letter, Password must contain at least one number"

#### Issue 3: Frontend Shows "CrashLoopBackOff"

**Symptom**: Frontend pod keeps restarting.

**Cause**: Nginx trying to resolve `api-gateway` before it's deployed.

**Fix**:
```bash
# Deploy API Gateway first
kubectl apply -f k8s/deployments/api-gateway.yaml

# Wait for API Gateway to be ready
kubectl wait --for=condition=ready pod -l app=api-gateway --timeout=60s -n payflow

# Then restart frontend
kubectl delete pod -n payflow -l app=frontend
```

#### Issue 4: Port-Forward Connection Refused

**Symptom**: `curl http://localhost:8080` returns "Connection refused".

**Cause**: Port-forward process stopped or crashed.

**Fix**:
```bash
# Check if port-forward is running
ps aux | grep "kubectl port-forward" | grep -v grep

# If not running, restart it
kubectl port-forward service/frontend 8080:80 -n payflow &
kubectl port-forward service/api-gateway 3000:80 -n payflow &
```

#### Issue 5: HTTP 500 Internal Server Error

**Symptom**: Registration/login returns 500 error.

**Possible Causes**:
1. Database connection issue
2. Service dependency not ready
3. Circuit breaker open

**Fix**:
```bash
# Check service logs
kubectl logs -n payflow -l app=auth-service --tail=20
kubectl logs -n payflow -l app=api-gateway --tail=20

# Check if services are healthy
kubectl get pods -n payflow

# Restart problematic service
kubectl delete pod -n payflow -l app=auth-service
```

### Step 13: Final Working State

**✅ Complete Deployment Status**:

- **Infrastructure** (3 services):
  - ✅ PostgreSQL (StatefulSet) - 1 pod
  - ✅ Redis (Deployment) - 1 pod
  - ✅ RabbitMQ (Deployment) - 1 pod

- **Backend Services** (4 services):
  - ✅ Auth Service - 2 replicas
  - ✅ Wallet Service - 2 replicas
  - ✅ Notification Service - 2 replicas
  - ✅ Transaction Service - 3 replicas (HPA: 2-10)

- **API Gateway** (1 service):
  - ✅ API Gateway - 2 replicas (LoadBalancer)

- **Frontend** (1 service):
  - ✅ Frontend - 1 pod

- **Backup System** (1 CronJob):
  - ✅ PostgreSQL Backup - Daily at 2 AM UTC (10GB storage, 7-day retention)

- **Autoscaling** (6 HPAs):
  - ✅ API Gateway HPA - 2-10 replicas (aggressive scaling)
  - ✅ Auth Service HPA - 2-8 replicas
  - ✅ Wallet Service HPA - 2-8 replicas
  - ✅ Notification Service HPA - 2-6 replicas
  - ✅ Frontend HPA - 2-6 replicas
  - ✅ Transaction Service HPA - 2-10 replicas

- **Jobs** (2 jobs):
  - ✅ Database Migration Job - Completed (creates tables on first deploy)
  - ✅ Transaction Timeout Handler CronJob - Runs every minute (auto-reverses stuck transactions)

- **Security** (1 CronJob):
  - ✅ Image Scanning CronJob - Runs daily at 3 AM UTC (scans all images for vulnerabilities)

**Total**: 15 pods running, all healthy + 1 Backup CronJob + 1 Timeout Handler CronJob + 1 Image Scanning CronJob + 1 Migration Job + 6 HPAs

**Access Points**:
- Frontend: `http://localhost:8080` (via port-forward)
- API Gateway: `http://localhost:3000` (via port-forward)
- API Gateway LoadBalancer: `http://10.1.254.100` (if MetalLB enabled)

**Application Features Working**:
- ✅ User Registration with password validation
- ✅ User Login
- ✅ Wallet Management
- ✅ Money Transfers
- ✅ Transaction History
- ✅ Notifications

### Step 14: Deploy Database Backup System

#### 14.1 Overview

**What it does**: Automatically creates compressed PostgreSQL database backups daily at 2 AM UTC, stores them in a persistent volume, and deletes backups older than 7 days to manage storage.

**Why you're adding it**: To protect against data loss from database corruption, accidental deletions, or cluster failures by maintaining automated daily backups with a 7-day retention period for disaster recovery.

**Understanding Backup Jobs**:
- **CronJob**: The scheduled job definition (in `postgres-backup.yaml`)
- **Automatic Jobs**: Created by CronJob at 2 AM UTC daily (named `postgres-backup-<timestamp>`)
- **Manual Jobs**: Created when you run `kubectl create job --from=cronjob/postgres-backup` (named `manual-backup-<timestamp>`, `test-backup-<timestamp>`, etc.)
- **All jobs** use the same template and create backups in the same location (`/backups` in the PVC)
- **Job History**: CronJob keeps last 3 successful and 3 failed jobs (configured in YAML)

#### 14.2 Deploy Backup CronJob

**File**: `k8s/backup/postgres-backup.yaml`

**Components**:
1. **CronJob**: Runs backup job daily at 2 AM UTC
2. **PersistentVolumeClaim**: 10GB storage for backup files
3. **Backup Script**: Uses `pg_dump` to create compressed SQL dumps

**Deploy**:
```bash
kubectl apply -f k8s/backup/postgres-backup.yaml
```

**Verify**:
```bash
# Check CronJob
kubectl get cronjob -n payflow postgres-backup

# Check PVC
kubectl get pvc -n payflow postgres-backup-pvc

# Check CronJob details
kubectl describe cronjob postgres-backup -n payflow
```

**Expected Output**:
```
NAME              SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
postgres-backup   0 2 * * *   <none>     False     0        <none>          3s

NAME                    STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS        AGE
postgres-backup-pvc     Pending  <none>   <unset>   RWO            microk8s-hostpath   3s
```

**Note**: PVC may show "Pending" initially. This is normal because `microk8s-hostpath` uses `WaitForFirstConsumer` binding mode. The PVC will bind automatically when the first backup job runs and tries to use it.

**After first backup job runs**:
```
NAME                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
postgres-backup-pvc     Bound    pvc-c3a3e53b-207b-433f-972f-0aefa4fe6d28   10Gi       RWO            microk8s-hostpath   4m
```

**Verify backup job completed**:
```bash
# Check job status
kubectl get jobs -n payflow | grep postgres-backup

# View backup logs
kubectl logs -n payflow -l job-name --tail=10

# Expected output:
# Starting PostgreSQL backup...
# Backup completed: /backups/payflow-20251225-125158.sql.gz (4.0K)
# Cleaned up old backups (>7 days)
```

#### 14.3 Backup Configuration

**Schedule**: `0 2 * * *` (Daily at 2 AM UTC)
- `0` = minute (0)
- `2` = hour (2 AM)
- `*` = day of month (every day)
- `*` = month (every month)
- `*` = day of week (every day)

**Retention**: 7 days
- Backups older than 7 days are automatically deleted
- Keeps approximately 7 backup files (one per day)

**Storage**: 10GB PersistentVolumeClaim
- Backup files are stored in `/backups` directory
- Files are compressed (`.sql.gz` format)
- Format: `payflow-YYYYMMDD-HHMMSS.sql.gz`

#### 14.4 Manual Backup Trigger

To trigger a backup immediately (without waiting for scheduled time):

```bash
# Create a one-time job from the CronJob
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%s) -n payflow

# Check job status
kubectl get jobs -n payflow | grep manual-backup

# View job logs
kubectl logs -n payflow -l job-name=manual-backup-<timestamp>
```

**Note**: When you create manual jobs like this, they appear in `kubectl get jobs` with names like `manual-backup-<timestamp>`, `test-backup-<timestamp>`, etc. These are NOT in the YAML file - they're created dynamically from the CronJob template. The CronJob keeps the last 3 successful and 3 failed jobs for history.

#### 14.5 Check Backup Files

**Why you see "test-backup" and "manual-backup" jobs**: These are one-time jobs created FROM the CronJob (not in the YAML). When you run `kubectl create job --from=cronjob/postgres-backup`, Kubernetes creates a new Job that uses the same template as the CronJob. The CronJob itself only creates jobs automatically at the scheduled time (2 AM UTC daily).

**Method 1: Use Backup Viewer Pod (Recommended)**

Create a temporary pod to view backup files:

```bash
# Deploy backup viewer pod
kubectl apply -f k8s/backup/backup-viewer.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod backup-viewer -n payflow --timeout=30s

# List all backup files
kubectl exec -it backup-viewer -n payflow -- ls -lh /backups

# View backup file details
kubectl exec -it backup-viewer -n payflow -- sh -c "ls -lh /backups && echo '' && echo 'Total backups:' && ls -1 /backups | wc -l"

# Check backup file sizes
kubectl exec -it backup-viewer -n payflow -- du -sh /backups/*

# Clean up when done
kubectl delete pod backup-viewer -n payflow
```

**Method 2: Check from Completed Backup Pod**

If a backup job just completed, you can check its logs:

```bash
# Find the most recent backup pod
kubectl get pods -n payflow -l job-name --sort-by=.metadata.creationTimestamp | grep backup | tail -1

# View backup logs (shows file name and size)
kubectl logs -n payflow -l job-name --tail=5 | grep "Backup completed"

# Expected output:
# Backup completed: /backups/payflow-20251225-125657.sql.gz (4.0K)
```

**Method 3: Check Backup Job History**

```bash
# List all backup jobs (including test/manual ones)
kubectl get jobs -n payflow | grep backup

# View logs from latest backup job
LATEST_JOB=$(kubectl get jobs -n payflow | grep backup | tail -1 | awk '{print $1}')
kubectl logs -n payflow -l job-name=$LATEST_JOB --tail=10

# Check which jobs are from CronJob vs manual
kubectl get jobs -n payflow -o wide | grep backup
```

**Understanding Backup Job Names**:
- `postgres-backup-<timestamp>`: Created automatically by CronJob at scheduled time
- `test-backup-<timestamp>`: Created manually for testing
- `manual-backup-<timestamp>`: Created manually for on-demand backups
- `list-backups-<timestamp>`: Created manually to check backups

All these jobs use the same template from the CronJob, so they all create backups in the same location (`/backups`).

#### 14.6 Restore from Backup

To restore a backup file:

```bash
# 1. Get the backup file name
kubectl exec -it <backup-pod> -n payflow -- ls /backups

# 2. Copy backup file to local machine (if needed)
kubectl cp <namespace>/<backup-pod>:/backups/payflow-20251225-020000.sql.gz ./restore.sql.gz

# 3. Restore to PostgreSQL
kubectl exec -it postgres-0 -n payflow -- bash

# Inside postgres pod:
gunzip < /backups/payflow-20251225-020000.sql.gz | psql -U payflow -d payflow

# Or from host:
kubectl exec -i postgres-0 -n payflow -- \
  bash -c "gunzip < /backups/payflow-20251225-020000.sql.gz | psql -U payflow -d payflow"
```

**Note**: Restore operations should be done during maintenance windows as they may cause downtime.

#### 14.7 Monitor Backup Jobs

```bash
# View all backup jobs (includes scheduled and manual ones)
kubectl get jobs -n payflow | grep backup

# View only CronJob-created jobs (filter by label if needed)
kubectl get jobs -n payflow -l app=postgres-backup

# View logs from latest backup job
LATEST_JOB=$(kubectl get jobs -n payflow | grep backup | tail -1 | awk '{print $1}')
kubectl logs -n payflow -l job-name=$LATEST_JOB --tail=10

# Check CronJob status and next scheduled run
kubectl get cronjob postgres-backup -n payflow

# View CronJob details
kubectl describe cronjob postgres-backup -n payflow
```

**Quick Check Commands**:
```bash
# Quick status check
kubectl get cronjob, jobs, pvc -n payflow | grep backup

# Check if backups are being created
kubectl logs -n payflow -l job-name --tail=5 | grep "Backup completed"

# Count backup files
kubectl exec backup-viewer -n payflow -- ls -1 /backups | wc -l
```

#### 14.8 Troubleshooting Backups

**Issue: PVC stuck in Pending**
```bash
# Check storage class
kubectl get storageclass

# If microk8s-hostpath doesn't exist, update PVC:
kubectl patch pvc postgres-backup-pvc -n payflow -p '{"spec":{"storageClassName":""}}'
```

**Issue: Backup job fails**
```bash
# Check job logs
kubectl logs -n payflow -l job-name --tail=100

# Common causes:
# 1. Database connection failed - check postgres service
# 2. Insufficient permissions - check secret credentials
# 3. Storage full - check PVC usage
```

**Issue: Backups not running**
```bash
# Check CronJob is not suspended
kubectl get cronjob postgres-backup -n payflow

# Manually trigger a job to test
kubectl create job --from=cronjob/postgres-backup test-backup -n payflow

# Check job status
kubectl get job test-backup -n payflow
```

#### 14.9 Backup Best Practices

1. **Test Restores Regularly**: Periodically test restoring from backups to ensure they work
2. **Monitor Storage**: Check PVC usage to ensure backups don't fill up storage
3. **Off-Site Backups**: For production, consider copying backups to external storage (S3, NFS, etc.)
4. **Backup Verification**: The backup script verifies backup file creation before completing
5. **Retention Policy**: Adjust retention period based on your needs (currently 7 days)

**Example: Copy backups to external storage** (future enhancement):
```bash
# Add to backup script to copy to S3/NFS after creation
aws s3 cp "$BACKUP_FILE" s3://payflow-backups/
```

### Step 15: Deploy Horizontal Pod Autoscalers (HPA)

#### 15.1 Overview

**What it does**: Automatically scales the number of pod replicas up or down based on CPU and memory utilization, ensuring optimal resource usage and handling traffic spikes without manual intervention.

**Why you're adding it**: 
- **Cost Optimization**: Scale down during low traffic to save resources
- **Performance**: Scale up automatically during traffic spikes to maintain response times
- **Reliability**: Prevents service overload by adding capacity before resources are exhausted
- **Hands-off Operation**: No manual scaling needed - Kubernetes handles it automatically

**How it works**:
1. HPA continuously monitors CPU and memory usage of pods
2. When metrics exceed target thresholds (e.g., 70% CPU), HPA increases replicas
3. When metrics drop below thresholds, HPA decreases replicas (with stabilization delay)
4. Scaling happens within min/max replica limits you configure

#### 15.2 HPA Configuration

**File**: `k8s/autoscaling/hpa.yaml`

**Services with HPA**:
1. **API Gateway** - 2-10 replicas (handles all incoming traffic)
2. **Auth Service** - 2-8 replicas (login/registration spikes)
3. **Wallet Service** - 2-8 replicas (balance checks, updates)
4. **Notification Service** - 2-6 replicas (message processing)
5. **Frontend** - 2-6 replicas (user traffic)
6. **Transaction Service** - 2-10 replicas (already defined in deployment)

**Scaling Metrics**:
- **CPU Target**: 70% utilization
- **Memory Target**: 80% utilization
- HPA scales when **either** metric exceeds threshold

**Scaling Behavior** (API Gateway example):
- **Scale Up**: Immediate (no delay)
  - Can double pods (100% increase) OR add 2 pods at a time
  - Uses the policy that scales the most
- **Scale Down**: 5-minute stabilization window
  - Reduces by 50% at a time (prevents rapid scale-down)

#### 15.3 Deploy HPAs

**Prerequisites**:
- Metrics-server must be enabled (already enabled in MicroK8s setup)
- Deployments must have resource requests/limits defined (already configured)

**Deploy**:
```bash
kubectl apply -f k8s/autoscaling/hpa.yaml
```

**Verify**:
```bash
# Check all HPAs
kubectl get hpa -n payflow

# Expected output:
# NAME                      REFERENCE                TARGETS                        MINPODS   MAXPODS   REPLICAS   AGE
# api-gateway-hpa           Deployment/api-gateway   <unknown>/70%, <unknown>/80%   2         10        2          5s
# auth-service-hpa          Deployment/auth-service  <unknown>/70%, <unknown>/80%   2         8         2          5s
# wallet-service-hpa        Deployment/wallet-service <unknown>/70%, <unknown>/80%  2         8         2          5s
# notification-service-hpa  Deployment/notification-service <unknown>/70%, <unknown>/80% 2  6         2          5s
# frontend-hpa              Deployment/frontend      <unknown>/70%, <unknown>/80%   2         6         2          5s
```

**Note**: `<unknown>` is normal initially. Metrics will appear after metrics-server collects data (usually within 1-2 minutes).

#### 15.4 Monitor HPA Activity

**Check HPA Status**:
```bash
# View all HPAs with current metrics
kubectl get hpa -n payflow

# View detailed HPA information
kubectl describe hpa api-gateway-hpa -n payflow

# Watch HPA in real-time
kubectl get hpa -n payflow -w
```

**Expected Output** (after metrics are collected):
```
NAME                REFERENCE              TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
api-gateway-hpa     Deployment/api-gateway  45%/70%, 60%/80%  2         10        2          2m
auth-service-hpa    Deployment/auth-service 30%/70%, 50%/80%  2         8         2          2m
```

**Check Scaling Events**:
```bash
# View HPA events
kubectl describe hpa api-gateway-hpa -n payflow | grep -A 10 Events

# Check deployment replicas (should match HPA)
kubectl get deployments -n payflow
```

#### 15.5 Understanding HPA Behavior

**When HPA Scales Up**:
- CPU usage > 70% OR Memory usage > 80% (averaged across all pods)
- HPA calculates: `desiredReplicas = ceil(currentReplicas * (currentMetricValue / targetMetricValue))`
- Example: 2 pods at 90% CPU → `ceil(2 * (90/70)) = ceil(2.57) = 3 pods`

**When HPA Scales Down**:
- CPU usage < 70% AND Memory usage < 80% (both must be below threshold)
- Waits for stabilization window (5 minutes for API Gateway) before scaling down
- Reduces gradually (50% at a time) to prevent rapid fluctuations

**Scaling Limits**:
- **Min Replicas**: HPA will never scale below this (ensures high availability)
- **Max Replicas**: HPA will never scale above this (prevents resource exhaustion)

#### 15.6 Test HPA Scaling

**Generate Load to Trigger Scale-Up**:
```bash
# Install hey (load testing tool) if not installed
# macOS: brew install hey
# Linux: go install github.com/rakyll/hey@latest

# Generate load on API Gateway
hey -n 10000 -c 50 http://localhost:3000/health

# Watch HPA scale up
kubectl get hpa api-gateway-hpa -n payflow -w

# Check pod count increase
kubectl get pods -n payflow -l app=api-gateway
```

**Wait for Scale-Down**:
```bash
# Stop load generation
# Wait 5+ minutes (stabilization window)

# Watch HPA scale down
kubectl get hpa api-gateway-hpa -n payflow -w

# Check pod count decrease
kubectl get pods -n payflow -l app=api-gateway
```

#### 15.7 HPA Configuration Details

**API Gateway HPA** (Most aggressive scaling):
```yaml
minReplicas: 2
maxReplicas: 10
scaleUp: Immediate, can double or add 2 pods
scaleDown: 5-minute delay, 50% reduction
```

**Auth/Wallet Services HPA**:
```yaml
minReplicas: 2
maxReplicas: 8
scaleUp: Standard (immediate)
scaleDown: Standard (immediate)
```

**Notification/Frontend Services HPA**:
```yaml
minReplicas: 2
maxReplicas: 6
scaleUp: Standard (immediate)
scaleDown: Standard (immediate)
```

**Transaction Service HPA** (in deployment file):
```yaml
minReplicas: 2
maxReplicas: 10
scaleUp: Standard (immediate)
scaleDown: Standard (immediate)
```

#### 15.8 Related Documentation

**Cluster Autoscaling Guide**: For information about cluster-level autoscaling (scaling nodes, not just pods), multi-node MicroK8s setup, and cloud autoscaling options (EKS/AKS/GKE), see [Cluster Autoscaling Guide](cluster-autoscaling.md).

**Topics Covered**:
- Understanding Pod Autoscaling (HPA) vs Cluster Autoscaler
- Multi-node MicroK8s cluster setup (manual node management)
- Cloud autoscaling options (EKS/AKS/GKE with Cluster Autoscaler)
- When to use each autoscaling approach

#### 15.9 Troubleshooting HPA

**Issue: HPA shows `<unknown>` metrics or "FailedGetResourceMetric" errors**

**Error Message**:
```
Warning  FailedGetResourceMetric  horizontal-pod-autoscaler  failed to get cpu utilization: 
unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: 
the server could not find the requested resource (get pods.metrics.k8s.io)
```

**Cause**: Metrics-server is not running or not properly enabled, even though it may show as "enabled" in MicroK8s status.

**Solution**:
```bash
# Re-enable metrics-server (this ensures it's actually running)
microk8s enable metrics-server

# Wait for metrics-server pod to start
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=60s

# Verify metrics-server is running
kubectl get pods -n kube-system | grep metrics-server

# Test if metrics are available
kubectl top nodes
kubectl top pods -n payflow

# Check HPA again (should show metrics now)
kubectl describe hpa api-gateway-hpa -n payflow | grep -A 3 "Metrics:"
```

**Expected Output** (after fix):
```
Metrics:  ( current / target )
  resource cpu on pods:    5% (12m) / 70%
  resource memory on pods: 16% (43276288) / 80%
```

**Note**: Even if `microk8s status` shows metrics-server as enabled, it may not be running. Re-enabling ensures the pod is created and running.

**Issue: HPA not scaling up**
```bash
# Check if pods have resource requests defined
kubectl describe deployment api-gateway -n payflow | grep -A 5 "Requests:"

# Check current resource usage
kubectl top pods -n payflow

# Verify HPA is targeting the correct deployment
kubectl describe hpa api-gateway-hpa -n payflow | grep "Scale Target"
```

**Issue: HPA scaling too aggressively**
```bash
# Adjust stabilization window
kubectl edit hpa api-gateway-hpa -n payflow

# Increase stabilizationWindowSeconds for scaleDown
# Or adjust target utilization percentages
```

**Issue: HPA not scaling down**
```bash
# Check if both CPU and memory are below thresholds
kubectl top pods -n payflow

# Check HPA events
kubectl describe hpa api-gateway-hpa -n payflow | grep Events

# Verify minReplicas isn't preventing scale-down
kubectl get hpa api-gateway-hpa -n payflow -o jsonpath='{.spec.minReplicas}'
```

#### 15.10 Best Practices

1. **Set Appropriate Min Replicas**: 
   - Minimum 2 for high availability
   - More for critical services (API Gateway)

2. **Set Realistic Max Replicas**:
   - Based on cluster capacity
   - Consider cost implications

3. **Monitor Scaling Behavior**:
   - Watch for rapid scaling (thrashing)
   - Adjust stabilization windows if needed

4. **Resource Requests Required**:
   - HPA needs resource requests to calculate utilization
   - All PayFlow services already have requests/limits defined

5. **Test Under Load**:
   - Verify HPA scales appropriately during traffic spikes
   - Ensure scale-down doesn't cause service degradation

6. **Combine with Resource Limits**:
   - HPA scales pods, but resource limits prevent individual pod overload
   - Both work together for optimal performance

### Step 16: Deploy Transaction Timeout Handler

#### 16.1 Overview

**What it does**: Automatically reverses pending transactions that have been stuck for more than 1 minute.

**Why you need it**:
- **Mimics Real Bank Behavior**: Real banks auto-reverse stuck/failed transactions
- **Prevents Fund Locking**: Without it, user funds stay locked in pending transactions forever
- **Improves User Experience**: Users don't have to wait indefinitely for failed transactions
- **System Reliability**: Handles edge cases where transactions get stuck due to service failures

**What happens without it**:
- ❌ **Funds Locked**: User money stuck in pending transactions indefinitely
- ❌ **Poor UX**: Users see "pending" transactions that never complete
- ❌ **Manual Intervention Required**: Admins must manually reverse stuck transactions
- ❌ **Database Bloat**: Pending transactions accumulate over time
- ❌ **User Complaints**: Users can't access their money

**How it works**:
1. CronJob runs every minute
2. Finds all transactions with status `PENDING` older than 1 minute
3. Updates them to `FAILED` with timeout error message
4. Sets `completed_at` timestamp
5. Logs count of reversed transactions

**Real-World Scenario**:
- User initiates $100 transfer
- Transaction service crashes before completing
- Transaction stays in `PENDING` status
- User's $100 is deducted but recipient never receives it
- **With Timeout Handler**: After 1 minute, transaction auto-reversed, user's money returned
- **Without Timeout Handler**: Money stuck forever until manual intervention

#### 16.2 Deploy Transaction Timeout Handler

**File**: `k8s/jobs/transaction-timeout-handler.yaml`

**Deploy**:
```bash
kubectl apply -f k8s/jobs/transaction-timeout-handler.yaml
```

**Verify**:
```bash
# Check CronJob
kubectl get cronjob -n payflow transaction-timeout-handler

# Check recent jobs created by CronJob
kubectl get jobs -n payflow | grep transaction-timeout

# View job logs (from most recent run)
LATEST_JOB=$(kubectl get jobs -n payflow | grep transaction-timeout | tail -1 | awk '{print $1}')
kubectl logs -n payflow -l job-name=$LATEST_JOB --tail=10
```

**Expected Output**:
```
NAME                           SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
transaction-timeout-handler    * * * * *     False     1        15s             1m

NAME                                    COMPLETIONS   DURATION   AGE
transaction-timeout-handler-1766667400  1/1           3s         1m
```

#### 16.3 Understanding the Timeout Handler

**Cron Schedule**: `* * * * *` (every minute)
- `*` = minute (every minute)
- `*` = hour (every hour)
- `*` = day of month (every day)
- `*` = month (every month)
- `*` = day of week (every day)

**Why Every Minute?**:
- Fast response time for stuck transactions
- Minimal overhead (simple SQL query)
- Users get their money back quickly

**Safety Checks**:
- Only reverses transactions older than 1 minute (prevents race conditions)
- Checks for newer completed transactions (prevents reversing if transaction actually completed)
- Uses `IF NOT EXISTS` patterns to prevent duplicate reversals

**Job History**:
- `successfulJobsHistoryLimit: 3` - Keeps last 3 successful runs for debugging
- `failedJobsHistoryLimit: 1` - Keeps last 1 failed run for troubleshooting

#### 16.4 Monitor Transaction Timeouts

**Check Reversed Transactions**:
```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow

# Query reversed transactions
SELECT id, from_wallet_id, to_wallet_id, amount, status, error_message, completed_at
FROM transactions
WHERE status = 'FAILED'
AND error_message LIKE '%automatically reversed%'
ORDER BY completed_at DESC
LIMIT 10;
```

**Check Pending Transactions**:
```bash
# Count pending transactions
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "
SELECT COUNT(*) as pending_count, 
       MIN(created_at) as oldest_pending,
       MAX(created_at) as newest_pending
FROM transactions 
WHERE status = 'PENDING';"
```

**View CronJob Activity**:
```bash
# Watch CronJob create new jobs every minute
kubectl get jobs -n payflow -w | grep transaction-timeout

# Check CronJob events
kubectl describe cronjob transaction-timeout-handler -n payflow | grep -A 10 Events
```

#### 16.5 Troubleshooting Transaction Timeout Handler

**Issue: CronJob not creating jobs**
```bash
# Check CronJob status
kubectl get cronjob transaction-timeout-handler -n payflow

# Check if CronJob is suspended
kubectl get cronjob transaction-timeout-handler -n payflow -o jsonpath='{.spec.suspend}'
# Should be: false

# Manually trigger a job to test
kubectl create job --from=cronjob/transaction-timeout-handler test-timeout-$(date +%s) -n payflow
```

**Issue: Jobs failing**
```bash
# Check job logs
kubectl logs -n payflow -l job-name --tail=50 | grep -i error

# Common causes:
# 1. Database connection failed - check postgres service
# 2. Wrong table schema - check if transactions table exists
# 3. Permission issues - check database user credentials
```

**Issue: Too many transactions being reversed**
```bash
# Check if timeout is too short (currently 1 minute)
# Review transaction processing time in your application
# Consider increasing timeout if legitimate transactions take longer

# Check transaction service logs for processing delays
kubectl logs -n payflow -l app=transaction-service --tail=100 | grep -i "processing\|timeout"
```

#### 16.6 Best Practices

1. **Monitor Reversal Rate**:
   - High reversal rate indicates transaction service issues
   - Investigate why transactions are getting stuck

2. **Adjust Timeout if Needed**:
   - If legitimate transactions take > 1 minute, increase timeout
   - Update the SQL query: `INTERVAL '1 minute'` → `INTERVAL '5 minutes'`

3. **Alert on High Reversals**:
   - Set up monitoring to alert if > X transactions reversed per hour
   - Indicates systemic issues with transaction processing

4. **Review Reversed Transactions**:
   - Periodically review why transactions were reversed
   - Identify patterns (specific users, amounts, times)

5. **Test the Handler**:
   - Create a test pending transaction
   - Wait 1+ minute
   - Verify it gets automatically reversed

### Step 17: Deploy Container Image Scanning (Security)

#### 17.1 Overview

**What it does**: Automatically scans all PayFlow container images daily for known security vulnerabilities (CVEs) using Trivy, a security scanner.

**Why you need it**:
- **Security Compliance**: Detects vulnerabilities before they reach production
- **Early Detection**: Finds security issues in base images and dependencies
- **Risk Mitigation**: Identifies HIGH and CRITICAL vulnerabilities that need immediate attention
- **Compliance Requirements**: Many organizations require regular security scanning
- **Shift Left Security**: Catch issues early in the deployment pipeline

**What happens without it**:
- ❌ **Unknown Vulnerabilities**: Deploy vulnerable images without knowing it
- ❌ **Security Breaches**: Attackers exploit known CVEs in your containers
- ❌ **Compliance Violations**: Fail security audits and compliance checks
- ❌ **Data Breaches**: Vulnerable containers can be compromised, leading to data theft
- ❌ **Reputation Damage**: Security incidents damage trust and reputation
- ❌ **No Visibility**: No way to track vulnerability trends over time

**Real-World Scenario**:
- Base image (node:18-alpine) has a critical CVE discovered
- Without scanning: You deploy it unknowingly, attacker exploits it
- With scanning: Daily scan detects it, you update to patched version before breach

#### 17.2 How Image Scanning Works

**Trivy Scanner**:
- Open-source security scanner by Aqua Security
- Scans container images for known CVEs (Common Vulnerabilities and Exposures)
- Checks base images, installed packages, and dependencies
- Maintains database of known vulnerabilities

**Scan Process**:
1. CronJob runs daily at 3 AM UTC
2. Pulls each PayFlow image from registry
3. Scans image layers for vulnerabilities
4. Generates JSON report with findings
5. Reports only HIGH and CRITICAL severity issues
6. Stores reports in temporary volume

**What Gets Scanned**:
- Base images (node:18-alpine, postgres:15-alpine, etc.)
- Installed packages (npm packages, system packages)
- Application dependencies
- All layers of the container image

#### 17.3 Deploy Image Scanning CronJob

**Files Available**:
- `k8s/security/image-scanning-cronjob.yaml` - Docker version (for Docker environments)
- `k8s/security/image-scanning-cronjob-containerd.yaml` - Containerd version (for MicroK8s)

**For MicroK8s (Containerd)**:
```bash
# Deploy containerd version
kubectl apply -f k8s/security/image-scanning-cronjob-containerd.yaml
```

**For Docker Environments**:
```bash
# Deploy Docker version
kubectl apply -f k8s/security/image-scanning-cronjob.yaml
```

**Prerequisites**:
- **Docker version**: Docker must be running on the node (for Docker socket access)
- **Containerd version**: Containerd socket must be accessible (MicroK8s has this by default)
- Images must be available in registry or locally

**Key Differences**:

| Feature | Docker Version | Containerd Version | Registry Version |
|---------|---------------|-------------------|------------------|
| **Socket** | `/var/run/docker.sock` | `/run/containerd/containerd.sock` | None (pulls from registry) |
| **Image Source** | Local Docker daemon | Local containerd | Remote registry |
| **Image Format** | `payflow/api-gateway:latest` | `payflow/api-gateway:latest` | `registry/path/image:tag` |
| **Use Case** | Docker Desktop, Docker Engine | MicroK8s, containerd clusters | Docker Hub, ECR, ACR, GCR |
| **Authentication** | Not needed | Not needed | Required for private repos |
| **File** | `image-scanning-cronjob.yaml` | `image-scanning-cronjob-containerd.yaml` | `image-scanning-cronjob-registry.yaml` |

**Which is Better?**

**For Local Development (MicroK8s)**:
- ✅ **Containerd Version** - Best choice
  - Images are already in containerd
  - No need to push to registry
  - Faster (no network pull)
  - No authentication needed

**For Production (EKS/AKS/Docker Hub)**:
- ✅ **Registry Version** - Best choice
  - Images are in registry anyway
  - Works across all environments
  - Centralized scanning
  - No socket access needed (more secure)

**For Docker Desktop**:
- ✅ **Docker Version** - Best choice
  - Uses Docker socket directly
  - Simple setup

**Recommendation**:
- **Local/MicroK8s**: Use containerd version
- **Production/EKS/AKS**: Use registry version
- **Docker Desktop**: Use Docker version

**Verify**:
```bash
# Check CronJob
kubectl get cronjob -n payflow image-scanning

# Check if job has run
kubectl get jobs -n payflow | grep image-scanning

# View scan logs
LATEST_JOB=$(kubectl get jobs -n payflow | grep image-scanning | tail -1 | awk '{print $1}')
kubectl logs -n payflow -l job-name=$LATEST_JOB
```

**Expected Output**:
```
NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
image-scanning    0 3 * * *     False     0        <none>          5s
```

#### 17.3.1 Test Scan (Manual Trigger)

**What is a test scan?**: A one-time job created manually from the CronJob to test if the scanning works immediately, without waiting for the scheduled time (3 AM UTC).

**Why create it?**:
- **Immediate Testing**: Verify the CronJob works without waiting until 3 AM
- **Troubleshooting**: Test configuration changes immediately
- **Validation**: Ensure images are accessible and scanning works
- **Debugging**: Check logs and fix issues before the scheduled run

**How to create a test scan**:
```bash
# Create a one-time job from the CronJob
kubectl create job --from=cronjob/image-scanning test-scan-$(date +%s) -n payflow

# Check job status
kubectl get jobs -n payflow | grep test-scan

# View scan logs
kubectl logs -n payflow -l job-name --tail=50

# Check if scan completed
kubectl get pods -n payflow | grep test-scan
```

**Understanding the command**:
- `kubectl create job --from=cronjob/image-scanning`: Creates a Job using the CronJob's template
- `test-scan-$(date +%s)`: Unique job name with timestamp (prevents conflicts)
- The job uses the same container image, script, and configuration as the CronJob

**Note**: Test scans are NOT in the YAML file - they're created dynamically when you run the command. The CronJob itself only creates jobs automatically at the scheduled time.

#### 17.3.2 Scan Images from Registries (Docker Hub, EKS, AKS)

**When to Use**: Images are stored in container registries (Docker Hub, AWS ECR, Azure ACR, Google GCR)

**File**: `k8s/security/image-scanning-cronjob-registry.yaml`

**How It Works**:
- Trivy pulls images directly from registry
- No Docker/containerd socket needed
- Requires authentication for private registries
- Works in any Kubernetes environment (EKS, AKS, GKE, etc.)

**Deploy**:
```bash
# 1. Create registry secrets (if using private repos)
kubectl create secret generic registry-secrets -n payflow \
  --from-literal=DOCKERHUB_USERNAME=yourusername \
  --from-literal=DOCKERHUB_PASSWORD=yourpassword

# 2. Update image URLs in the YAML file to match your registry
# Edit: k8s/security/image-scanning-cronjob-registry.yaml

# 3. Deploy
kubectl apply -f k8s/security/image-scanning-cronjob-registry.yaml
```

**Registry-Specific Configuration**:

**Docker Hub**:
```yaml
IMAGES="
docker.io/yourusername/payflow-api-gateway:latest
docker.io/yourusername/payflow-auth-service:latest
"
# Authentication: Use DOCKERHUB_USERNAME and DOCKERHUB_PASSWORD from secrets
```

**AWS ECR (EKS)**:
```yaml
IMAGES="
123456789012.dkr.ecr.us-east-1.amazonaws.com/payflow-api-gateway:latest
123456789012.dkr.ecr.us-east-1.amazonaws.com/payflow-auth-service:latest
"
# Authentication: Use AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
# Or use IAM roles (IRSA) for EKS - no credentials needed
```

**Azure ACR (AKS)**:
```yaml
IMAGES="
yourregistry.azurecr.io/payflow-api-gateway:latest
yourregistry.azurecr.io/payflow-auth-service:latest
"
# Authentication: Use AZURE_CLIENT_ID and AZURE_CLIENT_SECRET
# Or use managed identity for AKS - no credentials needed
```

**Google GCR (GKE)**:
```yaml
IMAGES="
gcr.io/your-project/payflow-api-gateway:latest
gcr.io/your-project/payflow-auth-service:latest
"
# Authentication: Use service account key
```

**Advantages of Registry Scanning**:
- ✅ **Works Everywhere**: EKS, AKS, GKE, any Kubernetes
- ✅ **More Secure**: No socket access needed
- ✅ **Centralized**: Scan images in one place
- ✅ **CI/CD Integration**: Scan before deployment
- ✅ **No Local Dependencies**: Doesn't need Docker/containerd on nodes

**Disadvantages**:
- ❌ **Network Required**: Must pull images from registry
- ❌ **Slower**: Network latency for image pulls
- ❌ **Authentication**: Need credentials for private repos
- ❌ **Cost**: Registry pull costs (if applicable)

#### 17.4 Understanding the Scan Configuration

**Schedule**: `0 3 * * *` (Daily at 3 AM UTC)
- Low traffic time
- Scans complete before business hours
- Can adjust based on your timezone

**Images Scanned**:
- `payflow/api-gateway:latest`
- `payflow/auth-service:latest`
- `payflow/wallet-service:latest`
- `payflow/transaction-service:latest`
- `payflow/notification-service:latest`
- `payflow/frontend:latest`

**Severity Levels**:
- **CRITICAL**: Immediate action required (remote code execution, etc.)
- **HIGH**: Should be fixed soon (privilege escalation, etc.)
- **MEDIUM/LOW**: Not scanned (can be added if needed)

**Report Format**: JSON
- Easy to parse programmatically
- Can integrate with alerting systems
- Suitable for trend analysis

#### 17.5 View Scan Results

**Method 1: Check Scan Logs (Quick Summary)**

```bash
# Get latest scan job
LATEST_JOB=$(kubectl get jobs -n payflow | grep image-scanning | tail -1 | awk '{print $1}')

# View scan output (summary)
kubectl logs -n payflow -l job-name=$LATEST_JOB

# Expected output:
# Starting image vulnerability scan...
# Scanning docker.io/veeno/api-gateway:latest...
# Found 5 vulnerabilities in docker.io/veeno/api-gateway:latest
# Scanning docker.io/veeno/auth-service:latest...
# Found 2 vulnerabilities in docker.io/veeno/auth-service:latest
# ...
# Scan complete. Reports saved to /reports
```

**Method 2: View Detailed JSON Reports (If Pod Still Running)**

```bash
# Get pod name
SCAN_POD=$(kubectl get pods -n payflow -l job-name | grep image-scanning | tail -1 | awk '{print $1}')

# Check if pod is still running
kubectl get pod $SCAN_POD -n payflow

# List report files
kubectl exec -it $SCAN_POD -n payflow -- ls -lh /reports

# View a specific report (formatted JSON)
kubectl exec -it $SCAN_POD -n payflow -- cat /reports/docker-io-veeno-api-gateway-latest-20251225.json | jq .

# Count vulnerabilities per image
kubectl exec -it $SCAN_POD -n payflow -- sh -c "
  for file in /reports/*.json; do
    echo \"\$(basename \$file):\"
    jq '[.Results[]?.Vulnerabilities[]?] | length' \$file 2>/dev/null || echo '0'
  done
"
```

**Method 3: Extract Reports Before Pod Terminates**

```bash
# Get pod name
SCAN_POD=$(kubectl get pods -n payflow -l job-name | grep image-scanning | tail -1 | awk '{print $1}')

# Copy reports to local machine
kubectl cp payflow/$SCAN_POD:/reports ./scan-reports

# View reports locally
ls -lh ./scan-reports/
cat ./scan-reports/docker-io-veeno-api-gateway-latest-20251225.json | jq .

# Analyze vulnerabilities
jq '.Results[]?.Vulnerabilities[]? | {vulnerability: .VulnerabilityID, severity: .Severity, package: .PkgName}' ./scan-reports/*.json | jq -s 'group_by(.severity) | map({severity: .[0].severity, count: length})'
```

**Method 4: Scan Images Directly with Trivy (Local Testing)**

```bash
# Install Trivy locally (if not installed)
# macOS: brew install trivy
# Linux: See https://aquasecurity.github.io/trivy/latest/getting-started/installation/

# Scan image from Docker Hub
trivy image veeno/api-gateway:latest

# Scan with JSON output
trivy image --format json --output scan-results.json veeno/api-gateway:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL veeno/api-gateway:latest

# Scan all PayFlow images
for image in veeno/api-gateway veeno/auth-service veeno/wallet-service veeno/transaction-service veeno/notification-service veeno/frontend; do
  echo "Scanning $image:latest..."
  trivy image --severity HIGH,CRITICAL $image:latest
done
```

**Method 5: View Scan Results from Registry CronJob**

If using the registry scanning CronJob (`image-scanning-registry`):

```bash
# Get latest registry scan job
LATEST_JOB=$(kubectl get jobs -n payflow | grep image-scanning-registry | tail -1 | awk '{print $1}')

# View logs
kubectl logs -n payflow -l job-name=$LATEST_JOB

# Extract reports (same as Method 3)
SCAN_POD=$(kubectl get pods -n payflow -l job-name=$LATEST_JOB | tail -1 | awk '{print $1}')
kubectl cp payflow/$SCAN_POD:/reports ./registry-scan-reports
```

**Understanding Scan Results**:

```json
{
  "Results": [
    {
      "Target": "docker.io/veeno/api-gateway:latest",
      "Class": "os-pkgs",
      "Type": "alpine",
      "Vulnerabilities": [
        {
          "VulnerabilityID": "CVE-2024-12345",
          "PkgName": "openssl",
          "InstalledVersion": "3.0.0",
          "FixedVersion": "3.0.1",
          "Severity": "CRITICAL",
          "Title": "OpenSSL vulnerability",
          "Description": "Remote code execution possible..."
        }
      ]
    }
  ]
}
```

**Key Fields**:
- `VulnerabilityID`: CVE identifier (e.g., CVE-2024-12345)
- `Severity`: CRITICAL, HIGH, MEDIUM, LOW
- `PkgName`: Package with vulnerability
- `InstalledVersion`: Current version
- `FixedVersion`: Version that fixes the issue
- `Title`: Brief description
- `Description`: Detailed explanation

**Note**: Reports are stored in `emptyDir` volume, so they're lost when the pod terminates. In production, mount a PersistentVolume or upload to S3/cloud storage.

#### 17.6 Production Enhancements

**Current Limitations**:
- Reports stored in temporary volume (lost on pod restart)
- No alerting when vulnerabilities found
- No integration with CI/CD
- No long-term storage

**Production Recommendations**:

1. **Persistent Storage**:
```yaml
# Replace emptyDir with PVC
volumes:
- name: reports
  persistentVolumeClaim:
    claimName: scan-reports-pvc
```

2. **Upload to S3**:
```bash
# Add to scan script
aws s3 cp /reports/* s3://payflow-security-scans/$(date +%Y/%m)/
```

3. **Alerting**:
```bash
# Send Slack/email if critical vulnerabilities found
if [ "$VULNS" -gt 0 ]; then
  curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK \
    -d "{\"text\":\"⚠️ Found $VULNS vulnerabilities in $IMAGE\"}"
fi
```

4. **CI/CD Integration**:
- Block deployments if critical vulnerabilities found
- Require security scan to pass before merging PRs
- Fail builds if new vulnerabilities introduced

5. **Dashboard**:
- Store scan results in database
- Create Grafana dashboard showing vulnerability trends
- Track which images have most vulnerabilities

#### 17.7 Troubleshooting Image Scanning

**Issue: CronJob not creating jobs**
```bash
# Check CronJob status
kubectl get cronjob image-scanning -n payflow

# Check if suspended
kubectl get cronjob image-scanning -n payflow -o jsonpath='{.spec.suspend}'

# Manually trigger
kubectl create job --from=cronjob/image-scanning test-scan-$(date +%s) -n payflow
```

**Issue: "Cannot connect to Docker daemon"**
```bash
# Check if Docker socket exists on node
# For MicroK8s VM:
multipass exec microk8s-vm -- ls -la /var/run/docker.sock

# If Docker not installed in VM, install it:
multipass exec microk8s-vm -- sudo apt-get update
multipass exec microk8s-vm -- sudo apt-get install -y docker.io
```

**Issue: "Image not found"**

**Problem**: Images are in MicroK8s containerd, but Trivy is configured for Docker.

**Solution Options**:

**Option 1: Use Containerd Socket (Recommended for MicroK8s)**

Update the CronJob to use containerd instead of Docker:

```bash
# Edit the image scanning CronJob
kubectl edit cronjob image-scanning -n payflow
```

**Changes needed**:
1. Replace Docker socket mount with containerd socket:
```yaml
volumeMounts:
- name: containerd-socket
  mountPath: /run/containerd/containerd.sock
  # Remove: docker-socket mount

volumes:
- name: containerd-socket
  hostPath:
    path: /run/containerd/containerd.sock
    type: Socket
  # Remove: docker-socket volume
```

2. Update Trivy command to use containerd:
```bash
# Change from:
trivy image "$IMAGE"

# To:
trivy image "containerd://$IMAGE"
```

**Or use the pre-configured containerd version**:
```bash
# Deploy containerd version
kubectl apply -f k8s/security/image-scanning-cronjob-containerd.yaml

# Delete Docker version
kubectl delete cronjob image-scanning -n payflow
```

**Option 2: Export Images and Scan Tar Files**

```bash
# Export image from containerd
multipass exec microk8s-vm -- sudo microk8s ctr images export /tmp/api-gateway.tar docker.io/payflow/api-gateway:latest

# Transfer to host
multipass transfer microk8s-vm:/tmp/api-gateway.tar /tmp/api-gateway.tar

# Scan the tar file
trivy image --input /tmp/api-gateway.tar
```

**Option 3: Push to Registry and Scan from There**

```bash
# Tag and push images to Docker Hub (or your registry)
docker tag payflow/api-gateway:latest your-registry/payflow-api-gateway:latest
docker push your-registry/payflow-api-gateway:latest

# Trivy can then pull and scan from registry
trivy image your-registry/payflow-api-gateway:latest
```

**Verify Images Exist**:
```bash
# Check if images exist in containerd
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep payflow
```

**Issue: Scan taking too long**
```bash
# Trivy downloads vulnerability database on first run
# Subsequent scans are faster (database cached)
# Consider:
# - Running scans less frequently
# - Using Trivy with offline database
# - Scanning only changed images
```

**Issue: Too many false positives**
```bash
# Adjust severity filter
# Change --severity HIGH,CRITICAL to --severity CRITICAL
# Or add --ignorefile to ignore known false positives
```

#### 17.7.1 Choosing the Right Scanning Method

**Decision Matrix**:

| Scenario | Best Choice | Why |
|----------|-------------|-----|
| **MicroK8s (Local Dev)** | Containerd Version | Images already in containerd, fastest, no auth needed |
| **Docker Desktop** | Docker Version | Uses Docker socket directly, simple setup |
| **EKS (AWS)** | Registry Version (ECR) | Images in ECR, use IAM roles (IRSA), no credentials |
| **AKS (Azure)** | Registry Version (ACR) | Images in ACR, use managed identity, no credentials |
| **GKE (Google)** | Registry Version (GCR) | Images in GCR, use service accounts |
| **Docker Hub (Public)** | Registry Version | Simple, no auth needed for public repos |
| **Docker Hub (Private)** | Registry Version | Requires credentials, but works everywhere |
| **Multi-Cloud** | Registry Version | Works across all environments consistently |

**Quick Reference**:

```bash
# MicroK8s (Local)
kubectl apply -f k8s/security/image-scanning-cronjob-containerd.yaml

# Docker Desktop
kubectl apply -f k8s/security/image-scanning-cronjob.yaml

# EKS/AKS/Docker Hub (Production)
kubectl apply -f k8s/security/image-scanning-cronjob-registry.yaml
```

#### 17.8 Best Practices

1. **Regular Scanning**:
   - Scan daily (current setup) or on image updates
   - Scan before deploying to production
   - Scan in CI/CD pipeline

2. **Severity Focus**:
   - Start with CRITICAL and HIGH only
   - Add MEDIUM/LOW if needed for compliance
   - Focus on actionable findings

3. **Remediation Process**:
   - Create tickets for each critical vulnerability
   - Prioritize by severity and exploitability
   - Track remediation progress

4. **Image Updates**:
   - Keep base images updated (latest security patches)
   - Update dependencies regularly
   - Use minimal base images (alpine, distroless)

5. **Monitoring**:
   - Track vulnerability trends over time
   - Alert on new critical vulnerabilities
   - Review scan reports regularly

6. **Documentation**:
   - Document why certain vulnerabilities are accepted (if any)
   - Keep audit trail of scans
   - Report to security team regularly

### Step 18: Accessing Services (Alternative Methods)

**Note**: For detailed port-forwarding instructions, see [Step 11: Accessing the Application](#step-11-accessing-the-application).

#### 14.1 Using LoadBalancer (If MetalLB Enabled)

If MetalLB is enabled in MicroK8s, the API Gateway LoadBalancer will have an external IP:

```bash
# Get LoadBalancer IP
kubectl get service -n payflow api-gateway

# Access API Gateway directly
curl http://10.1.254.100/health
```

**Note**: Frontend still needs port-forwarding as it's a ClusterIP service.

#### 14.2 Using NodePort (Alternative)

You can change the frontend service to NodePort for direct access:

```bash
# Edit frontend service
kubectl edit service frontend -n payflow

# Change type from ClusterIP to NodePort
# Save and exit

# Get NodePort
kubectl get service -n payflow frontend

# Access via NodePort (e.g., http://<node-ip>:<nodeport>)
```

#### 14.3 Using Ingress (Production)

For production, set up an Ingress controller:

```bash
# Enable ingress addon
microk8s enable ingress

# Create ingress resource
kubectl apply -f k8s/ingress/payflow-ingress.yaml
```

**Note**: Ingress configuration is not included in this guide. See Kubernetes Ingress documentation for details.

# Access from Windows browser
# Use: http://localhost:8080
# WSL2 automatically forwards ports to Windows
```

#### 9.2 Service DNS Names
Within the cluster, services are accessible via DNS:
- `postgres.payflow.svc.cluster.local:5432`
- `redis.payflow.svc.cluster.local:6379`
- `rabbitmq.payflow.svc.cluster.local:5672`
- `auth-service.payflow.svc.cluster.local:3004`

Short names also work within the same namespace:
- `postgres:5432`
- `auth-service:3004`

### Common Issues and Solutions

#### Issue 1: kubectl Connection Refused

**macOS / Linux**:
```bash
# Solution: Reconfigure kubectl
microk8s config > ~/.kube/microk8s-config
export KUBECONFIG=~/.kube/microk8s-config
kubectl get nodes
```

**Windows (PowerShell)**:
```powershell
# If using Multipass VM:
multipass exec microk8s-vm -- microk8s config > $env:USERPROFILE\.kube\microk8s-config
$env:KUBECONFIG = "$env:USERPROFILE\.kube\microk8s-config"
kubectl get nodes

# If using WSL2:
wsl microk8s config > $env:USERPROFILE\.kube\microk8s-config
$env:KUBECONFIG = "$env:USERPROFILE\.kube\microk8s-config"
kubectl get nodes
```

**Windows (WSL2)**:
```bash
# Inside WSL2:
microk8s config > ~/.kube/microk8s-config
export KUBECONFIG=~/.kube/microk8s-config
kubectl get nodes
```

#### Issue 2: Image Not Found

**macOS (Multipass VM)**:
```bash
# Check if image exists in containerd
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep <image-name>

# If missing, import it:
docker save <image> -o /tmp/image.tar
multipass transfer /tmp/image.tar microk8s-vm:/tmp/image.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/image.tar
```

**Windows (Multipass VM)**:
```powershell
# Check if image exists
multipass exec microk8s-vm -- sudo microk8s ctr images ls | grep <image-name>

# If missing, import it:
docker save <image> -o $env:TEMP\image.tar
multipass transfer $env:TEMP\image.tar microk8s-vm:/tmp/image.tar
multipass exec microk8s-vm -- sudo microk8s ctr images import /tmp/image.tar
```

**Windows (WSL2) / Linux (Native)**:
```bash
# Check if image exists
sudo microk8s ctr images ls | grep <image-name>

# If missing, import it:
docker save <image> -o /tmp/image.tar
sudo microk8s ctr images import /tmp/image.tar
rm /tmp/image.tar
```

#### Issue 3: Pod CrashLoopBackOff
```bash
# Check logs
kubectl logs <pod-name> -n payflow

# Check previous container logs
kubectl logs <pod-name> -n payflow --previous

# Describe pod for events
kubectl describe pod <pod-name> -n payflow
```

#### Issue 4: Frontend Can't Resolve API Gateway
- **Cause**: Nginx tries to resolve `api-gateway` at startup
- **Solution**: Deploy API Gateway first, or update nginx config to use resolver

#### Issue 5: Namespace Stuck in Terminating
```bash
# Remove finalizers
kubectl patch <resource-type> <resource-name> -n <namespace> \
  -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Deployment Order Summary

**Correct Dependency Order**:
1. ✅ **Infrastructure** (no dependencies):
   - PostgreSQL (StatefulSet)
   - Redis (Deployment)
   - RabbitMQ (Deployment)

2. ✅ **Backend Services** (deployed):
   - ✅ Auth Service (needs: PostgreSQL, Redis) - **2 replicas**
   - ✅ Wallet Service (needs: PostgreSQL, Redis) - **2 replicas**
   - ✅ Notification Service (needs: PostgreSQL, RabbitMQ) - **2 replicas**
   - ✅ Transaction Service (needs: PostgreSQL, Redis, RabbitMQ, Wallet Service) - **3 replicas with HPA (2-10)**

3. ⏳ **API Gateway** (needs: Auth, Wallet, Transaction services) - **Next to deploy**

4. ⏳ **Frontend** (needs: API Gateway) - **Will work after API Gateway**

**Current Status** (as of latest deployment):
- ✅ All infrastructure services running
- ✅ All backend services deployed and healthy
- ⏳ API Gateway - Ready to deploy (all dependencies met)
- ⏳ Frontend - Waiting for API Gateway

### Key Learnings

1. **StatefulSet vs Deployment**:
   - Use StatefulSet for databases (stable identity, ordered deployment)
   - Use Deployment for stateless services

2. **volumeClaimTemplates**:
   - Automatically creates PVCs per pod
   - Perfect for StatefulSets
   - Each pod gets its own persistent storage

3. **ConfigMaps and Secrets**:
   - ConfigMaps: Non-sensitive configuration
   - Secrets: Sensitive data (encrypted at rest)
   - Reference in deployments via `configMapKeyRef` and `secretKeyRef`

4. **Image Management in MicroK8s**:
   - MicroK8s uses containerd, not Docker
   - Import images using `microk8s ctr images import`
   - Use `imagePullPolicy: Never` for local images

5. **Service Discovery**:
   - Services accessible via DNS: `<service-name>.<namespace>.svc.cluster.local`
   - Short names work within same namespace
   - Headless services (StatefulSets) provide pod-specific DNS

6. **Horizontal Pod Autoscaler (HPA)**:
   - Automatically scales pods based on CPU/memory utilization
   - Transaction Service uses HPA: scales from 2 to 10 replicas at 70% CPU threshold
   - Requires metrics-server to be enabled
   - Initial CPU metrics may show `<unknown>` until metrics are collected
   - Example: `kubectl get hpa -n payflow` to view scaling status

7. **Deployment Replicas**:
   - Auth Service: 2 replicas (high availability)
   - Wallet Service: 2 replicas (high availability)
   - Notification Service: 2 replicas (high availability)
   - Transaction Service: 3 replicas initially, scales 2-10 via HPA (handles variable load)

8. **CronJobs for Automated Tasks**:
   - CronJobs run scheduled tasks (like database backups)
   - PostgreSQL backup runs daily at 2 AM UTC
   - Backups stored in PersistentVolumeClaim (10GB)
   - Automatic cleanup of backups older than 7 days
   - Can be manually triggered: `kubectl create job --from=cronjob/postgres-backup manual-backup -n payflow`

9. **Horizontal Pod Autoscaler (HPA)**:
   - Automatically scales pods based on CPU and memory utilization
   - Requires metrics-server to be enabled
   - All PayFlow services have HPA configured (2-10 replicas depending on service)
   - API Gateway has aggressive scale-up (can double pods immediately)
   - Scale-down has stabilization windows to prevent rapid fluctuations
   - HPA monitors both CPU (70% target) and memory (80% target)
   - Example: `kubectl get hpa -n payflow` to view all autoscalers

---

## Key Differences: Docker Compose vs Kubernetes

| Feature | Docker Compose | Kubernetes |
|---------|---------------|------------|
| **Orchestration** | Single host | Multi-node cluster |
| **Scaling** | Manual | Automatic (HPA) |
| **Load Balancing** | Basic | Advanced (Ingress) |
| **Self-Healing** | No | Yes (auto-restart) |
| **Service Discovery** | DNS | DNS + Labels |
| **Storage** | Volumes | PV/PVC |
| **Configuration** | .env files | ConfigMaps/Secrets |
| **Networking** | Bridge network | CNI plugins |
| **Updates** | Recreate | Rolling/Canary |
| **Production Ready** | No | Yes |

---

---

## Recent Updates and Additions

This section documents all recent additions and improvements to the PayFlow Kubernetes deployment.

### Update 1: Database Backup System (Step 14)

**Added**: Automated PostgreSQL backup CronJob

**Files Created**:
- `k8s/backup/postgres-backup.yaml` - Daily backup CronJob
- `k8s/backup/backup-viewer.yaml` - Helper pod to view backups

**Features**:
- Daily backups at 2 AM UTC
- 7-day retention (auto-cleanup)
- 10GB persistent storage
- Compressed SQL dumps

**Why Added**: Protect against data loss from corruption, accidental deletion, or cluster failures.

**Documentation**: See [Step 14: Deploy Database Backup System](#step-14-deploy-database-backup-system)

### Update 2: Horizontal Pod Autoscalers (Step 15)

**Added**: HPA configuration for all services

**Files Created**:
- `k8s/autoscaling/hpa.yaml` - HPAs for API Gateway, Auth, Wallet, Notification, Frontend

**Features**:
- Automatic scaling based on CPU (70%) and Memory (80%)
- API Gateway: 2-10 replicas (aggressive scaling)
- Other services: 2-8 replicas
- Scale-up: Immediate
- Scale-down: Stabilization windows

**Why Added**: Automatically handle traffic spikes, optimize resource usage, reduce costs.

**Documentation**: See [Step 15: Deploy Horizontal Pod Autoscalers (HPA)](#step-15-deploy-horizontal-pod-autoscalers-hpa)

### Update 3: Database Migration Job (Step 4.4)

**Added**: One-time job to create database schema

**Files Created**:
- `k8s/jobs/db-migration-job.yaml` - Creates tables and indexes

**Features**:
- Waits for PostgreSQL to be ready
- Creates users, wallets, transactions tables
- Creates performance indexes
- Safe to re-run (IF NOT EXISTS)

**Why Added**: Services fail without database tables. This ensures schema exists before services start.

**Documentation**: See [Step 4.4: Deploy Database Migration Job](#step-44-deploy-database-migration-job)

### Update 4: Transaction Timeout Handler (Step 16)

**Added**: CronJob to auto-reverse stuck transactions

**Files Created**:
- `k8s/jobs/transaction-timeout-handler.yaml` - Runs every minute

**Features**:
- Reverses pending transactions older than 1 minute
- Mimics real bank behavior
- Prevents funds from being locked forever

**Why Added**: Without it, user funds get stuck in pending transactions indefinitely.

**Documentation**: See [Step 16: Deploy Transaction Timeout Handler](#step-16-deploy-transaction-timeout-handler)

### Update 5: Container Image Scanning (Step 17)

**Added**: Automated security scanning with Trivy

**Files Created**:
- `k8s/security/image-scanning-cronjob.yaml` - Daily vulnerability scans

**Features**:
- Scans all PayFlow images daily at 3 AM UTC
- Detects HIGH and CRITICAL vulnerabilities
- Generates JSON reports
- Uses Trivy security scanner

**Why Added**: Detect security vulnerabilities before they reach production, comply with security requirements.

**Documentation**: See [Step 17: Deploy Container Image Scanning (Security)](#step-17-deploy-container-image-scanning-security)

### Update 6: Kubernetes Policies (Step 18)

**Added**: Network Policies, Pod Disruption Budgets, and Resource Quotas

**Files Created**:
- `k8s/policies/network-policies.yaml` - Network segmentation and security
- `k8s/policies/pod-disruption-budgets.yaml` - High availability during disruptions
- `k8s/policies/resource-quotas.yaml` - Resource limits per namespace

**Features**:
- **Network Policies**: Default deny all, explicit allow rules for service communication
- **Pod Disruption Budgets**: Ensures minimum pods available during updates/maintenance
- **Resource Quotas**: Limits total CPU, memory, and object counts per namespace

**Why Added**: 
- **Network Policies**: Prevent unauthorized pod-to-pod communication, limit attack surface
- **Pod Disruption Budgets**: Prevent service downtime during rolling updates and maintenance
- **Resource Quotas**: Prevent resource exhaustion, ensure fair allocation, enable multi-tenancy

**What Happens Without Them**:
- **Without Network Policies**: All pods can communicate freely (security risk)
- **Without PDBs**: All pods can be terminated simultaneously (downtime risk)
- **Without Resource Quotas**: Services can consume unlimited resources (stability risk)

**Documentation**: See [Step 18: Deploy Kubernetes Policies](#step-18-deploy-kubernetes-policies-network-pdb-resource-quotas)

### Update 8: Login Issues and Network Policy Fixes (Critical)

**Issue Date**: December 25, 2025

**Problem**: Login requests were failing with 502/504 Gateway Timeout errors after deploying ingress with HTTPS.

**Root Causes Identified**:

1. **Frontend Nginx DNS Resolution Failure**
   - **Symptom**: Frontend pods in `CrashLoopBackOff` with error: `host not found in upstream "api-gateway"`
   - **Cause**: Nginx tried to resolve `api-gateway` hostname at startup, but service wasn't ready yet
   - **Fix**: 
     - Added DNS resolver directive: `resolver 10.152.183.10 valid=10s;`
     - Used variable in `proxy_pass`: `set $api_gateway "http://api-gateway.payflow.svc.cluster.local:80";`
     - This forces DNS resolution at request time, not startup
   - **File**: `services/frontend/nginx.conf`

2. **REACT_APP_API_URL Build-Time vs Runtime Confusion**
   - **Symptom**: Setting `REACT_APP_API_URL` in Kubernetes deployment YAML had no effect
   - **Cause**: `REACT_APP_API_URL` is a **build-time** variable in React, not runtime
   - **Fix**: 
     - Removed env var from deployment YAML (useless)
     - Built Docker image with `/api` baked in: `docker build --build-arg REACT_APP_API_URL=/api`
     - Updated ingress to route `/api` path before `/` path (critical for nginx path matching)
   - **Files**: `k8s/deployments/frontend.yaml`, `k8s/ingress/tls-ingress-local.yaml`

3. **Missing Backend Service Ingress Network Policies**
   - **Symptom**: API Gateway received requests but couldn't reach auth-service (504 timeout)
   - **Cause**: Backend services had **egress** rules (can send) but **no ingress** rules (can't receive)
   - **Fix**: Added `backend-services-allow-ingress-from-api-gateway` network policy
   - **File**: `k8s/policies/network-policies.yaml`

4. **Missing Database Ingress Network Policies**
   - **Symptom**: Auth-service, notification-service, transaction-service in `CrashLoopBackOff` with Redis connection timeout
   - **Cause**: Databases (Redis, PostgreSQL, RabbitMQ) had **no ingress** rules to receive connections
   - **Fix**: Added `databases-allow-ingress-from-services` network policy
   - **File**: `k8s/policies/network-policies.yaml`

5. **Ingress Path Ordering Issue**
   - **Symptom**: `/api` requests routed to frontend instead of API Gateway
   - **Cause**: Ingress paths processed in order - `/` path caught everything before `/api` could match
   - **Fix**: Reordered ingress paths - `/api` must come **before** `/` path
   - **File**: `k8s/ingress/tls-ingress-local.yaml`

**Files Modified**:
- `services/frontend/nginx.conf` - Added DNS resolver and variable-based proxy_pass
- `k8s/deployments/frontend.yaml` - Removed useless REACT_APP_API_URL env var, set imagePullPolicy: Always
- `k8s/ingress/tls-ingress-local.yaml` - Fixed path ordering (/api before /)
- `k8s/policies/network-policies.yaml` - Added backend and database ingress policies

**Key Learnings**:
1. **Network Policies are Bidirectional**: Need both egress (sender) AND ingress (receiver) rules
2. **React Build-Time Variables**: `REACT_APP_*` vars must be set during `docker build`, not at runtime
3. **Nginx DNS Resolution**: Use resolver + variable to force lazy DNS resolution (request time, not startup)
4. **Ingress Path Matching**: More specific paths must come before less specific ones
5. **Default Deny Network Policies**: When using `default-deny-all`, every connection needs explicit allow rules

**Verification Commands**:
```bash
# Check all services are running
kubectl get deployments -n payflow

# Check network policies
kubectl get networkpolicies -n payflow

# Test API Gateway → auth-service connectivity
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=api-gateway -o jsonpath='{.items[0].metadata.name}') -- wget -qO- --timeout=3 http://auth-service:3004/health

# Test login endpoint
curl -k -X POST https://www.payflow.local/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123!"}'
```

**Result**: ✅ Login now works successfully! All services can communicate properly.

**Documentation**: See [Step 20.8: Troubleshooting Login Issues](#step-208-troubleshooting-login-issues) for detailed troubleshooting steps.

### Update 9: Transaction Failures and Wallet Service Network Policy Fix

**Issue Date**: December 25, 2025

**Problem**: All transactions were failing with "Failed" status. Transaction service could create transactions but couldn't complete them.

**Root Cause**:
- **Symptom**: Transactions created successfully but immediately marked as "Failed"
- **Cause**: Transaction service couldn't reach wallet-service to process transfers
- **Network Policy Issue**: 
  - Transaction service had **egress** rule to wallet-service (could send)
  - Wallet service had **NO ingress** rule from transaction-service (couldn't receive)
  - With `default-deny-all` policy, wallet-service rejected all incoming connections

**Fix Applied**:
- Added `wallet-service-allow-ingress-from-transaction` network policy
- Allows wallet-service to **receive** traffic from transaction-service on port 3001
- **File**: `k8s/policies/network-policies.yaml`

**How Transaction Flow Works**:
1. User initiates transaction via frontend
2. API Gateway → transaction-service (creates transaction, status: PENDING)
3. Transaction service → RabbitMQ (queues transaction for processing)
4. Transaction service worker → wallet-service (calls `/wallets/transfer`)
5. Wallet service → PostgreSQL (updates balances)
6. Transaction service → PostgreSQL (updates status to COMPLETED)
7. Transaction service → RabbitMQ (publishes notification event)

**Why It Failed**:
- Step 4 was blocked: transaction-service → wallet-service connection was denied
- Wallet service couldn't receive the transfer request
- Transaction timed out and was marked as FAILED

**Files Modified**:
- `k8s/policies/network-policies.yaml` - Added wallet-service ingress policy

**Key Learning**:
- **Network Policies are Bidirectional**: When using `default-deny-all`, BOTH sides need policies:
  - **Sender** needs egress rule (transaction-service-allow-wallet)
  - **Receiver** needs ingress rule (wallet-service-allow-ingress-from-transaction)
- **Service-to-Service Communication**: Every service-to-service call needs explicit network policy rules

**Verification Commands**:
```bash
# Check network policy exists
kubectl get networkpolicy wallet-service-allow-ingress-from-transaction -n payflow

# Test transaction-service → wallet-service connectivity
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=transaction-service -o jsonpath='{.items[0].metadata.name}') -- wget -qO- --timeout=3 http://wallet-service:3001/health

# Check transaction service logs
kubectl logs -n payflow -l app=transaction-service --tail=30 | grep -i "wallet\|transfer"

# Check wallet service logs
kubectl logs -n payflow -l app=wallet-service --tail=30 | grep -i "transfer"
```

**Result**: ✅ Transactions now complete successfully! Wallet service can receive and process transfer requests.

**Documentation**: See [Step 20.9: Troubleshooting Transaction Failures](#step-209-troubleshooting-transaction-failures) for detailed troubleshooting steps.

### Understanding Test Scans and Manual Jobs

**What are test scans/manual jobs?**:
- One-time jobs created manually from CronJobs
- Use the same template as the CronJob
- Allow immediate testing without waiting for scheduled time

**Why create them?**:
- **Immediate Testing**: Verify CronJob works without waiting for schedule
- **Troubleshooting**: Test configuration changes immediately
- **Validation**: Ensure everything works before scheduled run
- **Debugging**: Check logs and fix issues quickly

**How to create**:
```bash
# From any CronJob:
kubectl create job --from=cronjob/<cronjob-name> test-<name>-$(date +%s) -n payflow

# Examples:
kubectl create job --from=cronjob/postgres-backup test-backup-$(date +%s) -n payflow
kubectl create job --from=cronjob/image-scanning test-scan-$(date +%s) -n payflow
kubectl create job --from=cronjob/transaction-timeout-handler test-timeout-$(date +%s) -n payflow
```

**Note**: These jobs are NOT in the YAML files - they're created dynamically when you run the command. The CronJob itself only creates jobs automatically at the scheduled time.

**Job Naming**:
- `test-<name>-<timestamp>`: Manual test jobs
- `manual-<name>-<timestamp>`: Manual trigger jobs
- `<cronjob-name>-<timestamp>`: Automatically created by CronJob

All use the same template, so they all work the same way.

---

## Step 18: Deploy Kubernetes Policies (Network, PDB, Resource Quotas)

This step adds production-grade policies for network security, high availability, and resource management.

### 18.1 Network Policies

**Purpose**: Implement network segmentation and security controls

**Files**: `k8s/policies/network-policies.yaml`

**Why We Need This**:
- Prevents unauthorized pod-to-pod communication
- Implements "least privilege" network access
- Limits attack surface if a pod is compromised
- Enforces microservices security boundaries

**What Happens Without It**:
- All pods can communicate with each other (default Kubernetes behavior)
- If one pod is compromised, attacker can access all services
- No network-level isolation between services
- Difficult to detect unauthorized access attempts

**How It Works**:
- Default deny all traffic (`default-deny-all`)
- Explicitly allow only necessary connections
- Traffic is allowed only if it matches a policy rule
- Works at the network layer (before application layer)

**Policies Defined**:
1. **default-deny-all**: Denies all traffic by default
2. **api-gateway-allow-ingress**: Allows external traffic to API Gateway
3. **frontend-allow-ingress**: Allows external traffic to Frontend
4. **api-gateway-allow-egress**: Allows API Gateway to connect to backend services
5. **services-allow-db**: Allows backend services to connect to databases/queues
6. **transaction-service-allow-wallet**: Allows Transaction Service to call Wallet Service

**Deploy**:
```bash
kubectl apply -f k8s/policies/network-policies.yaml
```

**Verify**:
```bash
kubectl get networkpolicies -n payflow
```

**Note**: Network Policies require a CNI plugin that supports them. MicroK8s uses Calico by default, which supports Network Policies.

### 18.2 Pod Disruption Budgets (PDB)

**Purpose**: Ensure high availability during voluntary disruptions

**Files**: `k8s/policies/pod-disruption-budgets.yaml`

**Why We Need This**:
- Prevents all pods from being terminated simultaneously during:
  * Rolling updates (deployment updates)
  * Node maintenance (draining nodes)
  * Cluster upgrades
  * Manual pod deletions
- Ensures minimum service availability during disruptions
- Prevents service downtime during planned maintenance

**What Happens Without It**:
- All pods can be terminated at once during updates
- Service becomes completely unavailable during rolling updates
- No protection against accidental mass pod deletion
- Users experience downtime during deployments
- No guarantee of service availability during node maintenance

**How It Works**:
- Defines minimum available pods (`minAvailable`) or maximum unavailable (`maxUnavailable`)
- Kubernetes scheduler respects PDB during disruptions
- Prevents too many pods from being terminated simultaneously
- Works with Deployments, StatefulSets, and other controllers

**Example Scenario**:
- Transaction Service has 3 replicas
- PDB requires `minAvailable: 2`
- During rolling update, only 1 pod can be terminated at a time
- Ensures at least 2 pods are always serving traffic

**PDBs Defined**:
- **api-gateway-pdb**: minAvailable: 1 (out of 2 replicas)
- **auth-service-pdb**: minAvailable: 1 (out of 2 replicas)
- **wallet-service-pdb**: minAvailable: 1 (out of 2 replicas)
- **transaction-service-pdb**: minAvailable: 2 (out of 3+ replicas) - **Critical service**
- **notification-service-pdb**: minAvailable: 1 (out of 2 replicas)
- **frontend-pdb**: minAvailable: 1 (out of 2 replicas)

**Deploy**:
```bash
kubectl apply -f k8s/policies/pod-disruption-budgets.yaml
```

**Verify**:
```bash
kubectl get poddisruptionbudgets -n payflow
```

**Test**:
```bash
# Try to delete all pods - PDB will prevent it
kubectl delete pods -l app=transaction-service -n payflow
# Only 1 pod will be deleted at a time (to maintain minAvailable: 2)
```

### 18.3 Resource Quotas

**Purpose**: Limit total resource consumption per namespace

**Files**: `k8s/policies/resource-quotas.yaml`

**Why We Need This**:
- Prevents resource exhaustion (one service consuming all resources)
- Ensures fair resource allocation across services
- Protects cluster from runaway processes
- Enables multi-tenant environments (multiple namespaces)
- Helps with capacity planning and budgeting
- Prevents "noisy neighbor" problems

**What Happens Without It**:
- Services can consume unlimited resources
- One misbehaving service can starve others
- Cluster can run out of resources unexpectedly
- No protection against resource leaks
- Difficult to predict resource needs
- Can't enforce resource limits per namespace

**How It Works**:
- Sets hard limits on total resources in namespace
- Applies to all pods in the namespace
- Prevents new pods from being created if quota exceeded
- Works with Resource Requests and Limits in deployments
- Enforced at pod creation time

**Example Scenario**:
- Quota: 4 CPU requests, 8GB memory requests
- Service tries to create pod with 5 CPU request
- Pod creation fails: "exceeded quota"
- Forces proper resource planning

**Quotas Defined**:
- **CPU Requests**: 4 cores total
- **Memory Requests**: 8GB total
- **CPU Limits**: 8 cores total
- **Memory Limits**: 16GB total
- **Pods**: Maximum 20 pods
- **Services**: Maximum 10 services
- **PVCs**: Maximum 5 persistent volume claims
- **Secrets**: Maximum 10 secrets
- **ConfigMaps**: Maximum 15 configmaps

**Deploy**:
```bash
kubectl apply -f k8s/policies/resource-quotas.yaml
```

**Verify**:
```bash
kubectl get resourcequota -n payflow
kubectl describe resourcequota payflow-resource-quota -n payflow
```

**Check Usage**:
```bash
# See current resource usage vs. quota
kubectl describe resourcequota payflow-resource-quota -n payflow
```

**Example Output**:
```
Name:            payflow-resource-quota
Namespace:       payflow
Resource         Used    Hard
--------         ----    ----
limits.cpu       5       8
limits.memory    4Gi     16Gi
pods             12      20
requests.cpu     2.5     4
requests.memory  2Gi     8Gi
```

### 18.4 Deploy All Policies

Deploy all policies at once:

```bash
kubectl apply -f k8s/policies/
```

**Verify All Policies**:
```bash
# Network Policies
kubectl get networkpolicies -n payflow

# Pod Disruption Budgets
kubectl get poddisruptionbudgets -n payflow

# Resource Quotas
kubectl get resourcequota -n payflow
```

### 18.5 Testing Policies

**Test Network Policies**:
```bash
# Try to connect from unauthorized pod (should fail)
kubectl run test-pod --image=busybox -n payflow --rm -it -- sh
# Inside pod: wget -O- http://auth-service:3004/health
# Should fail if network policy is working
```

**Test Pod Disruption Budget**:
```bash
# Try to delete all transaction-service pods
kubectl delete pods -l app=transaction-service -n payflow
# Only 1 pod should be deleted at a time (PDB enforces minAvailable: 2)
```

**Test Resource Quota**:
```bash
# Try to create pod that exceeds quota
kubectl run test-pod --image=nginx --requests=cpu=5 -n payflow
# Should fail with "exceeded quota" error
```

### 18.6 Troubleshooting

**Issue**: Network Policies blocking legitimate traffic

**Solution**:
```bash
# Check network policies
kubectl get networkpolicies -n payflow
kubectl describe networkpolicy <policy-name> -n payflow

# Temporarily disable (for testing only)
kubectl delete networkpolicy default-deny-all -n payflow
```

**Issue**: Pod Disruption Budget preventing pod deletion

**Solution**:
```bash
# Check PDB
kubectl get poddisruptionbudgets -n payflow
kubectl describe poddisruptionbudget <pdb-name> -n payflow

# PDB is working as intended - it's protecting availability
# To force delete (not recommended), delete PDB first
```

**Issue**: Resource Quota preventing pod creation

**The Story**: Auth service was crashing, but the real problem was hidden. Here's what happened:

**Symptom**: Auth service in CrashLoopBackOff
```bash
kubectl get pods -n payflow -l app=auth-service
# Output: STATUS: CrashLoopBackOff
```

**First Check**: Auth service logs showed:
```
Error: getaddrinfo ENOTFOUND postgres
```

**What you think**: "PostgreSQL isn't running!"

**Second Check**: But when you check PostgreSQL:
```bash
kubectl get pods -n payflow | grep postgres
# Output: (empty - no pods!)
```

**The Real Problem**: PostgreSQL StatefulSet exists but can't create pods:
```bash
kubectl describe statefulset postgres -n payflow | tail -10
```

**The Error**:
```
Warning  FailedCreate  statefulset-controller  
create Pod postgres-0 in StatefulSet postgres failed error: 
pods "postgres-0" is forbidden: exceeded quota: payflow-resource-quota, 
requested: limits.cpu=1,requests.cpu=250m, 
used: limits.cpu=7900m,requests.cpu=3900m, 
limited: limits.cpu=8,requests.cpu=4
```

**What This Means**:
- Resource quota requires ALL pods to have resource requests/limits
- PostgreSQL StatefulSet was missing resource definitions
- Kubernetes refused to create the pod because it would exceed quota
- Auth service crashed because it couldn't connect to PostgreSQL (which wasn't running)

**The Fix**:

1. **Check current quota usage**:
```bash
kubectl get resourcequota payflow-resource-quota -n payflow -o jsonpath='{.status.used}' && echo
# Output: {"limits.cpu":"7900m","requests.cpu":"3900m",...}
# Available: Only 100m CPU requests, 100m CPU limits left
```

2. **Add resources to PostgreSQL StatefulSet** (`k8s/infrastructure/postgres.yaml`):
```yaml
containers:
- name: postgres
  # ... other config ...
  resources:
    requests:
      cpu: "100m"      # Fits within remaining quota
      memory: "256Mi"
    limits:
      cpu: "100m"      # Fits within remaining quota
      memory: "512Mi"
```

3. **Apply the fix**:
```bash
kubectl apply -f k8s/infrastructure/postgres.yaml
```

4. **Verify PostgreSQL starts**:
```bash
kubectl get pods -n payflow -l app=postgres
# Output: postgres-0   1/1   Running   0   81s
```

5. **Auth service recovers automatically**:
```bash
# Wait 10-15 seconds, then check
kubectl get pods -n payflow -l app=auth-service
# Output: All pods Running!
```

**The Lesson**:
- **Error messages can be misleading**: "ENOTFOUND postgres" made us think PostgreSQL wasn't running, but the real issue was that PostgreSQL couldn't start
- **Resource quotas are strict**: When a quota requires resource limits, ALL pods must have them
- **Check dependencies first**: When a service crashes, check if its dependencies are actually running
- **Always add resources**: Best practice is to always specify resource requests/limits for all pods

**Quick Diagnostic**:
```bash
# Check quota usage
kubectl describe resourcequota payflow-resource-quota -n payflow

# Check if pod creation is blocked by quota
kubectl describe statefulset <name> -n payflow | grep -A 5 Events

# Check available resources
kubectl get resourcequota -n payflow -o jsonpath='{.items[0].status.used}' && echo
```

**Alternative Solutions**:
- **Option 1**: Reduce resources in other services to free up quota
- **Option 2**: Increase resource quota limits (if cluster has capacity)
- **Option 3**: Remove resource quota (not recommended for production)

---

## Step 19: Docker Hub Integration and Security Hardening

This step covers pushing images to Docker Hub and adding security contexts to deployments.

### 19.1 Push Images to Docker Hub

**Purpose**: Make images available for sharing, CI/CD, and multi-environment deployment

**Prerequisites**:
- Docker Hub account (username: `veeno` in this example)
- Logged in to Docker Hub: `docker login`

**Push All Images**:
```bash
# Use the provided script
./push-to-dockerhub.sh veeno

# Or manually tag and push each image
docker tag payflow/api-gateway:latest veeno/api-gateway:latest
docker push veeno/api-gateway:latest
# Repeat for all services...
```

**Images Pushed**:
- `veeno/api-gateway:latest`
- `veeno/auth-service:latest`
- `veeno/wallet-service:latest`
- `veeno/transaction-service:latest`
- `veeno/notification-service:latest`
- `veeno/frontend:latest`

**Verify Images on Docker Hub**:
- Visit: https://hub.docker.com/u/veeno
- All images should be visible and publicly accessible (if public repo)

### 19.2 Update Deployments to Use Docker Hub Images

**Changes Required**:
1. Update image references from `payflow/*` to `veeno/*`
2. Change `imagePullPolicy` from `Never` to `IfNotPresent`

**Files Updated**:
- All deployment files in `k8s/deployments/`

**Apply Changes**:
```bash
kubectl apply -f k8s/deployments/
```

**Verify**:
```bash
# Check pods are using Docker Hub images
kubectl get pods -n payflow -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

### 19.3 Add Security Contexts

**Purpose**: Prevent privilege escalation and enforce non-root execution

**Security Contexts Added**:

**Node.js Services** (API Gateway, Auth, Wallet, Transaction, Notification):
```yaml
securityContext:
  allowPrivilegeEscalation: false  # Prevent privilege escalation
  runAsUser: 1000                  # Run as UID 1000 (node user)
  runAsGroup: 1000                  # Run as GID 1000
  readOnlyRootFilesystem: false     # Allow writes (logs, temp files)
```

**Frontend (Nginx)**:
```yaml
securityContext:
  allowPrivilegeEscalation: false  # Prevent privilege escalation
  # Note: nginx:alpine runs as root initially to create cache directories,
  # then drops privileges internally. We allow root but prevent escalation.
  readOnlyRootFilesystem: false     # Allow writes (logs, temp files)
```

**Why `runAsUser: 1000` Instead of `runAsNonRoot: true`?**:
- `runAsNonRoot: true` requires Kubernetes to verify the user is non-root
- Kubernetes can only verify if the user is specified as a numeric UID
- Node.js images use user name "nodejs" (non-numeric), causing verification to fail
- `runAsUser: 1000` explicitly sets UID 1000 (non-root, UID 0 is root)
- More reliable and equally secure

**Apply Security Contexts**:
```bash
# Security contexts are already in deployment files
kubectl apply -f k8s/deployments/
```

**Verify**:
```bash
# Check security contexts are applied
kubectl get pods -n payflow -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].securityContext.runAsUser}{"\n"}{end}'
```

### 19.4 Update Image Scanning for Docker Hub

**Update Registry Scanning CronJob**:
```bash
# Edit the registry scanning CronJob to use veeno/* images
kubectl apply -f k8s/security/image-scanning-cronjob-registry.yaml
```

**Images Scanned**:
- `docker.io/veeno/api-gateway:latest`
- `docker.io/veeno/auth-service:latest`
- `docker.io/veeno/wallet-service:latest`
- `docker.io/veeno/transaction-service:latest`
- `docker.io/veeno/notification-service:latest`
- `docker.io/veeno/frontend:latest`

**Test Registry Scan**:
```bash
# Create test scan job
kubectl create job --from=cronjob/image-scanning-registry test-registry-scan-$(date +%s) -n payflow

# View logs
kubectl logs -n payflow -l job-name --tail=50
```

### 19.5 Troubleshooting

**Issue: Pod fails with "CreateContainerConfigError"**

**Error**: `container has runAsNonRoot and image has non-numeric user (nodejs)`

**Solution**: Use `runAsUser: 1000` instead of `runAsNonRoot: true` (already fixed in deployments)

**Issue: Frontend pod fails with "Permission denied"**

**Error**: `mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)`

**Solution**: Remove `runAsUser` for frontend (nginx needs root to create cache directories, then drops privileges)

**Issue: Images not pulling from Docker Hub**

**Solution**:
```bash
# Check imagePullPolicy
kubectl get deployment api-gateway -n payflow -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'

# Should be: IfNotPresent

# Check if image exists on Docker Hub
docker pull veeno/api-gateway:latest
```

---

## Step 20: Configure Ingress with HTTPS (Local Development)

### 20.1 Overview

**What it does**: Routes external HTTPS traffic to internal services using self-signed certificates, mimicking production setup for local development.

**Why you're adding it**:
- ✅ **Production-like Setup**: Test HTTPS flow locally before deploying to production
- ✅ **Security Testing**: Verify SSL/TLS configuration works correctly
- ✅ **Learning**: Understand how ingress and TLS termination work
- ✅ **No Code Changes**: Same configuration works in AKS/EKS/GKE

**How it works**:
1. Generate self-signed TLS certificate
2. Create Kubernetes secret with certificate
3. Deploy ingress with TLS configuration
4. Browser accesses via HTTPS (with security warning - normal for self-signed)

### 20.2 Generate Self-Signed Certificate

**File**: `k8s/ingress/generate-tls-cert.sh`

```bash
# Generate certificate
cd k8s/ingress
./generate-tls-cert.sh
```

**What this creates**:
- `certs/tls.key` - Private key (keep secret!)
- `certs/tls.crt` - Certificate (valid for 365 days)

**Certificate includes**:
- `www.payflow.local` - Frontend domain
- `api.payflow.local` - API Gateway domain

### 20.3 Create Kubernetes Secret

```bash
# Create secret with certificate
kubectl create secret tls payflow-local-tls \
  --cert=k8s/ingress/certs/tls.crt \
  --key=k8s/ingress/certs/tls.key \
  -n payflow
```

**Verify**:
```bash
kubectl get secret payflow-local-tls -n payflow
```

### 20.4 Deploy TLS Ingress

```bash
# Deploy ingress with TLS
kubectl apply -f k8s/ingress/tls-ingress-local.yaml
```

**Verify**:
```bash
kubectl get ingress -n payflow
```

**Expected Output**:
```
NAME                    CLASS   HOSTS                                 ADDRESS   PORTS     AGE
payflow-local-ingress   nginx   api.payflow.local,www.payflow.local             80, 443   10s
```

### 20.5 Configure /etc/hosts

**macOS/Linux**:
```bash
# Get ingress IP (usually 192.168.64.2 for MicroK8s)
kubectl get ingress -n payflow -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'

# Add to /etc/hosts
sudo nano /etc/hosts
# Add: <ingress-ip> www.payflow.local api.payflow.local
```

**Windows**:
1. Open Notepad as Administrator
2. Open `C:\Windows\System32\drivers\etc\hosts`
3. Add: `<ingress-ip> www.payflow.local api.payflow.local`

### 20.6 Access Application

**Frontend**: `https://www.payflow.local`
**API**: `https://api.payflow.local`

**⚠️ Browser Security Warning**:
- Browsers will show "Your connection is not private"
- This is **normal** for self-signed certificates
- Click "Advanced" → Proceed to www.payflow.local (unsafe)"

### 20.7 Frontend API Configuration

**Important**: The frontend is configured to work in all environments automatically. See [Frontend API Configuration Guide](frontend-api-configuration.md) for details.

**Key Points**:
- ✅ Works with ingress (`/api` relative URL)
- ✅ Works without ingress (port-forwarding)
- ✅ Works in AKS/EKS/GKE (same configuration)
- ✅ Works in production (can override with real domain)

**Configuration**:
```yaml
env:
  - name: REACT_APP_API_URL
    value: "/api"  # Works everywhere!
```

**For different environments**, see [Frontend API Configuration Guide](frontend-api-configuration.md).

### 20.8 Troubleshooting Login Issues

**Issue: 502/504 Gateway Timeout on Login**

**Symptoms**:
- Browser shows "Request failed" or "504 Gateway Timeout"
- API Gateway logs show request received but no response
- Backend services in `CrashLoopBackOff`

**Diagnosis Steps**:

1. **Check if backend services are running**:
```bash
kubectl get pods -n payflow -l app=auth-service
kubectl get pods -n payflow -l app=notification-service
kubectl get pods -n payflow -l app=transaction-service
```

2. **Check service logs**:
```bash
kubectl logs -n payflow -l app=auth-service --tail=30
# Look for: "Connection timeout", "Connection refused", "Redis error"
```

3. **Test API Gateway → auth-service connectivity**:
```bash
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=api-gateway -o jsonpath='{.items[0].metadata.name}') -- wget -qO- --timeout=3 http://auth-service:3004/health
```

4. **Check network policies**:
```bash
kubectl get networkpolicies -n payflow
kubectl describe networkpolicy backend-services-allow-ingress-from-api-gateway -n payflow
kubectl describe networkpolicy databases-allow-ingress-from-services -n payflow
```

**Common Fixes**:

**Fix 1: Missing Backend Ingress Network Policy**

If API Gateway can't reach backend services:
```bash
# Verify policy exists
kubectl get networkpolicy backend-services-allow-ingress-from-api-gateway -n payflow

# If missing, apply it
kubectl apply -f k8s/policies/network-policies.yaml
```

**Fix 2: Missing Database Ingress Network Policy**

If services can't connect to Redis/PostgreSQL:
```bash
# Check if policy exists
kubectl get networkpolicy databases-allow-ingress-from-services -n payflow

# If missing, apply it
kubectl apply -f k8s/policies/network-policies.yaml

# Restart failing services
kubectl delete pods -n payflow -l app=auth-service
kubectl delete pods -n payflow -l app=notification-service
kubectl delete pods -n payflow -l app=transaction-service
```

**Fix 3: Frontend Nginx DNS Resolution**

If frontend pods are crashing:
```bash
# Check frontend logs
kubectl logs -n payflow -l app=frontend --tail=20 | grep "host not found"

# Verify nginx.conf has resolver and variable-based proxy_pass
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=frontend -o jsonpath='{.items[0].metadata.name}') -- cat /etc/nginx/conf.d/default.conf | grep -A 3 "location /api"
```

**Fix 4: Ingress Path Ordering**

If `/api` requests go to frontend instead of API Gateway:
```bash
# Check ingress configuration
kubectl get ingress payflow-local-ingress -n payflow -o yaml | grep -A 10 "www.payflow.local"

# Verify /api path comes BEFORE / path
# If not, update k8s/ingress/tls-ingress-local.yaml
```

**Issue: "Connection refused" or "This site can't be reached"**

**Check**:
1. Ingress is running: `kubectl get ingress -n payflow`
2. /etc/hosts is correct: `cat /etc/hosts | grep payflow`
3. Services are running: `kubectl get svc -n payflow`

**Issue: "Your connection is not private"**

**This is normal!** Self-signed certificates always show this warning. Click "Advanced" → "Proceed".

**Issue: Certificate Secret Not Found**

```bash
# Regenerate certificate
cd k8s/ingress
./generate-tls-cert.sh

# Create secret again
kubectl create secret tls payflow-local-tls \
  --cert=k8s/ingress/certs/tls.crt \
  --key=k8s/ingress/certs/tls.key \
  -n payflow
```

**Issue: Frontend Shows "Request failed" but No Specific Error**

**Check browser DevTools**:
1. Open DevTools (F12) → Network tab
2. Try login again
3. Check the `/api/auth/login` request:
   - **Status 502**: API Gateway can't reach auth-service (network policy issue)
   - **Status 504**: Request timeout (service not responding)
   - **Status 500**: Application error (check auth-service logs)

**Quick Diagnostic Script**:
```bash
#!/bin/bash
echo "🔍 PayFlow Login Diagnostic"
echo ""

echo "1. Checking services..."
kubectl get deployments -n payflow | grep -E "NAME|auth|api-gateway|frontend"

echo ""
echo "2. Checking pods..."
kubectl get pods -n payflow | grep -E "NAME|auth|api-gateway|frontend"

echo ""
echo "3. Checking network policies..."
kubectl get networkpolicies -n payflow

echo ""
echo "4. Testing API Gateway → auth-service..."
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=api-gateway -o jsonpath='{.items[0].metadata.name}') -- wget -qO- --timeout=3 http://auth-service:3004/health 2>&1 | head -3

echo ""
echo "5. Testing ingress → API Gateway..."
curl -k -s https://www.payflow.local/api/health -o /dev/null -w "HTTP Status: %{http_code}\n" 2>&1
```

### 20.9 Troubleshooting Transaction Failures

**Issue: All Transactions Show "Failed" Status**

**Symptoms**:
- Transactions are created but immediately marked as "Failed"
- Transaction history shows all transactions with red "Failed" status
- No error messages in frontend

**Diagnosis Steps**:

1. **Check if transaction service can reach wallet service**:
```bash
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=transaction-service -o jsonpath='{.items[0].metadata.name}') -- wget -qO- --timeout=3 http://wallet-service:3001/health
```

2. **Check transaction service logs**:
```bash
kubectl logs -n payflow -l app=transaction-service --tail=50 | grep -i "wallet\|transfer\|error\|timeout"
```

3. **Check wallet service logs**:
```bash
kubectl logs -n payflow -l app=wallet-service --tail=30 | grep -i "transfer"
```

4. **Check network policies**:
```bash
kubectl get networkpolicy -n payflow | grep wallet
kubectl describe networkpolicy wallet-service-allow-ingress-from-transaction -n payflow
kubectl describe networkpolicy transaction-service-allow-wallet -n payflow
```

**Common Fixes**:

**Fix 1: Missing Wallet Service Ingress Network Policy**

If transaction-service can't reach wallet-service:
```bash
# Verify policy exists
kubectl get networkpolicy wallet-service-allow-ingress-from-transaction -n payflow

# If missing, apply it
kubectl apply -f k8s/policies/network-policies.yaml
```

**Fix 2: Check RabbitMQ Connection**

If transaction service can't connect to RabbitMQ:
```bash
# Check RabbitMQ is running
kubectl get pods -n payflow -l app=rabbitmq

# Check transaction service logs for RabbitMQ errors
kubectl logs -n payflow -l app=transaction-service | grep -i "rabbitmq\|amqp"
```

**Fix 3: Check Database Connection**

If services can't connect to PostgreSQL:
```bash
# Check postgres is running
kubectl get pods -n payflow -l app=postgres

# Check database network policy
kubectl get networkpolicy databases-allow-ingress-from-services -n payflow
```

**Transaction Flow Verification**:
```bash
# 1. Create a test transaction via API
curl -k -X POST https://www.payflow.local/api/transactions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"toUserId":"user-123","amount":10.00}'

# 2. Check transaction status
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U payflow -d payflow -c "SELECT id, status, amount FROM transactions ORDER BY created_at DESC LIMIT 5;"

# 3. Monitor transaction processing
kubectl logs -n payflow -l app=transaction-service -f | grep -i "transaction\|processing"
```

**Quick Diagnostic Script**:
```bash
#!/bin/bash
echo "🔍 Transaction Failure Diagnostic"
echo ""

echo "1. Checking services..."
kubectl get pods -n payflow | grep -E "NAME|transaction|wallet|rabbitmq"

echo ""
echo "2. Testing transaction-service → wallet-service..."
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=transaction-service -o jsonpath='{.items[0].metadata.name}') -- wget -qO- --timeout=3 http://wallet-service:3001/health 2>&1 | head -3

echo ""
echo "3. Checking network policies..."
kubectl get networkpolicies -n payflow | grep -E "wallet|transaction"

echo ""
echo "4. Recent transaction service logs..."
kubectl logs -n payflow -l app=transaction-service --tail=10 | grep -i "error\|fail\|timeout" | tail -5
```

### 20.10 Related Documentation

- **Ingress Setup**: See `k8s/ingress/README.md` for detailed ingress configuration
- **Frontend API Configuration**: See [Frontend API Configuration Guide](frontend-api-configuration.md) for environment-specific setup
- **Production Ingress**: See `k8s/ingress/tls-ingress-letsencrypt.yaml` for Let's Encrypt setup

---

*Document created for PayFlow MicroK8s deployment*  
*Last updated: December 25, 2025*

