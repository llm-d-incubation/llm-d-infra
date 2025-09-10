# Platform Support: Apple Silicon MacBook

## Overview

This document provides platform-specific instructions for deploying llm-d-infra [simulator quickstart](https://github.com/llm-d-incubation/llm-d-infra/tree/main/quickstart/examples/sim/README) on Apple Silicon MacBooks. Due to ARM64 architecture differences, additional steps are required to build compatible container images.

## Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. To see what those tools are and minimum versions, check [our docs](https://github.com/llm-d-incubation/llm-d-infra/tree/main/quickstart/dependencies/README.md#required-tools), and to install them, see our [install-deps.sh](https://github.com/llm-d-incubation/llm-d-infra/blob/main/quickstart/dependencies/install-deps.sh) script.

**_NOTE:_** Unlike standard deployments, Apple Silicon MacBooks require building local ARM64 images for components that don't provide multi-architecture support.

## ARM64 Image Requirements

The simulator stack requires ARM64-compatible images that are not available in upstream registries. You must build these images before proceeding with any deployment option.

### llm-d Routing Sidecar (ARM64)

The `ghcr.io/llm-d/llm-d-routing-sidecar:v0.2.0` image lacks ARM64 support and must be built locally.

```bash
# 1. Clone the llm-d Routing Sidecar repository
cd /Users/$(whoami)/repos  # Adjust path as needed
git clone https://github.com/llm-d/llm-d-routing-sidecar.git
cd llm-d-routing-sidecar

# 2. Checkout the v0.2.0 tag for compatibility
git checkout v0.2.0

# 3. Build ARM64 image using the existing Dockerfile
podman build --platform=linux/arm64 -t localhost/llm-d-routing-sidecar:v0.2.0-arm64 .
```

### Gateway API Inference Extension EPP (ARM64)

```bash
# 1. Clone the Gateway API Inference Extension repository
cd /Users/$(whoami)/repos  # Adjust path as needed
git clone https://github.com/kubernetes-sigs/gateway-api-inference-extension.git
cd gateway-api-inference-extension

# 2. Checkout the v0.5.1 tag for compatibility
git checkout v0.5.1

# 3. Create ARM64-specific Dockerfile
cp Dockerfile Dockerfile.arm64

# 4. Edit Dockerfile.arm64 - change line 10 from:
# ENV GOARCH=amd64
# to:
# ENV GOARCH=arm64
sed -i '' 's/ENV GOARCH=amd64/ENV GOARCH=arm64/' Dockerfile.arm64

# 5. Build ARM64 image
podman build --platform=linux/arm64 -f Dockerfile.arm64 -t localhost/gateway-api-inference-extension-epp:v0.5.1-arm64 .
```

## Kind Cluster with Istio Gateway API

For users who prefer using kind instead of minikube, or want to test with the Istio Gateway API provider, follow these steps:

### Prerequisites for Kind Deployment

- kind installed
- Podman installed and configured
- kubectl configured

### Create Kind Cluster

Create the kind cluster with inline configuration:

```bash
kind create cluster --name llm-d-sim --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
EOF
```

### Install Gateway Provider Dependencies

```bash
cd quickstart/gateway-control-plane-providers
./install-gateway-provider-dependencies.sh
helmfile apply -f istio.helmfile.yaml
```

### Load ARM64 Images into Kind

After building the ARM64 images as described above, load them into kind. Since kind expects Docker but we're using Podman, we need to transfer images via tar files:

```bash
# Export images from podman
podman save localhost/llm-d-routing-sidecar:v0.2.0-arm64 -o /tmp/routing-sidecar-arm64.tar
podman save localhost/gateway-api-inference-extension-epp:v0.5.1-arm64 -o /tmp/epp-arm64.tar

# Load images into kind
kind load image-archive /tmp/routing-sidecar-arm64.tar --name llm-d-sim
kind load image-archive /tmp/epp-arm64.tar --name llm-d-sim

# Clean up temporary files
rm /tmp/routing-sidecar-arm64.tar /tmp/epp-arm64.tar
```

**IMPORTANT**: You must complete the image loading step BEFORE deploying the stack, otherwise the routing-sidecar pods will fail with `ImagePullBackOff` errors.

## Apple Silicon Override Files

The deployment uses permanent override files located in the `overrides/` directory:

- **`overrides/apple-silicon-ms-values.yaml`**: Contains ARM64 routing sidecar image overrides for the model service
- **`overrides/apple-silicon-gaie-values.yaml`**: Contains ARM64 EPP image overrides for the Gateway API Inference Extension

These files allow you to maintain consistent Apple Silicon configurations without modifying the base chart values.

### Deploy with Istio Gateway API

**Note**: The deployment commands below use the `apple-silicon` environment which automatically applies all ARM64 image overrides. This approach keeps the original values files unchanged while providing a clean environment-based configuration.

```bash
export NAMESPACE=llm-d-sim
kubectl create namespace ${NAMESPACE}
cd quickstart/examples/sim

# Deploy infrastructure first (no ARM64 overrides needed for infra)
helmfile apply -e apple-silicon -n ${NAMESPACE} --selector name=infra-sim

# Deploy GAIE with ARM64 image overrides using apple-silicon environment
helmfile apply -e apple-silicon -n ${NAMESPACE} --selector name=gaie-sim

# Deploy model service with ARM64 image overrides using apple-silicon environment
helmfile apply -e apple-silicon -n ${NAMESPACE} --selector name=ms-sim
```

## Verify the Installation

```bash
helm list -n ${NAMESPACE}
```

```bash
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
gaie-sim        llm-d-sim       1               2025-09-09 12:05:59.924531 -0400 EDT    deployed        inferencepool-v0.5.1            v0.5.1
infra-sim       llm-d-sim       1               2025-09-09 11:36:49.157159 -0400 EDT    deployed        llm-d-infra-v1.3.0              v0.3.0
ms-sim          llm-d-sim       1               2025-09-09 13:09:29.384851 -0400 EDT    deployed        llm-d-modelservice-v0.2.9       v0.2.0
```

- Out of the box with this example you should have the following resources:

```bash
kubectl get all -n ${NAMESPACE}
```

Expected output with ARM64 images (all pods `Running`):

```bash
kubectl get pods -n ${NAMESPACE}
NAME                                                 READY   STATUS    RESTARTS   AGE
gaie-sim-epp-76f5c7c955-pqmxb                        1/1     Running   0          5m3s
infra-sim-inference-gateway-istio-b78d598b4-crkx9    1/1     Running   0          5m3s
ms-sim-llm-d-modelservice-decode-6668d88ddc-6hmsm    2/2     Running   0          4m24s
ms-sim-llm-d-modelservice-decode-6668d88ddc-gg5wk    2/2     Running   0          3m53s
ms-sim-llm-d-modelservice-decode-6668d88ddc-k75wk    2/2     Running   0          4m56s
ms-sim-llm-d-modelservice-prefill-789dc68f7-s84ct    1/1     Running   0          5m2s
```

All decode pods should show `2/2` ready (init container + main container) and all other pods `1/1` ready. Note the gateway service is now `infra-sim-inference-gateway-istio` when using Istio.

## Using the stack

For instructions on getting started making inference requests see [our docs](https://github.com/llm-d-incubation/llm-d-infra/blob/main/quickstart/docs/getting-started-inferencing.md)

TL;DR

```bash
GATEWAY_SVC=$(kubectl get svc -n "${NAMESPACE}" -o yaml | yq '.items[] | select(.metadata.name | test(".*-inference-gateway(-.*)?$")).metadata.name' | head -n1)
```

```bash
export ENDPOINT="http://localhost:8000"
kubectl port-forward -n ${NAMESPACE} service/${GATEWAY_SVC} 8000:80
```

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
```

```bash
curl -X POST http://localhost:8000/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{
        "model": "random",
        "prompt": "How are you today?"
      }' | jq
```

### Cleanup Kind Deployment

To clean up the kind deployment:

```bash
# Remove the deployment
helmfile destroy -e apple-silicon -n ${NAMESPACE}

# Delete the kind cluster
kind delete cluster --name llm-d-sim
```

### Complete Cleanup (Start from Scratch)

To completely start from scratch and remove everything including the kind cluster:

```bash
# 1. Remove the deployment (if still running)
cd quickstart/examples/sim
helmfile destroy -e apple-silicon -n ${NAMESPACE}

# 2. Delete the kind cluster completely
kind delete cluster --name llm-d-sim

# 3. Clean up any remaining temporary files
rm -f /tmp/routing-sidecar-arm64.tar /tmp/epp-arm64.tar

# 4. Optional: Remove built images from podman (if you want to rebuild from scratch)
podman rmi localhost/llm-d-routing-sidecar:v0.2.0-arm64 2>/dev/null || true
podman rmi localhost/gateway-api-inference-extension-epp:v0.5.1-arm64 2>/dev/null || true
```

After this cleanup, you can start completely fresh by following the guide from the beginning.
