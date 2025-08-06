# Kind Development Deployment

This document describes how to use the `kind-deploy-sim.sh` script to set up a complete dev and simulation environment for `llm-d-infra` on a local `kind` cluster.

The script automates cluster creation, dependency installation, and the deployment of all necessary infrastructure charts.

-----

## Prerequisites

Before you begin, make sure you have the following tools installed. The script also runs [install-deps.sh](../../install-deps.sh) for any missing dependencies:

* **Podman/Docker**
* **[kind](https://kind.sigs.k8s.io/docs/user/quick-start/)**
* **git**

-----

## Usage

The deployment script must be run from the `llm-d-infra/quickstart` directory within the repository.

```bash
cd /path/to/llm-d-infra/quickstart
./kind-deploy-sim.sh [OPTIONS]
```

### **Options**

* `--gateway <name>`: Specify the gateway to use. Options are **kgateway** (default) or **istio**.
* `--skip-metrics`: Disables metrics collection during the infrastructure installation.
* `--help`: Displays the help menu.

### **Examples**

* **Default Deployment (kgateway)**

  ```bash
  ./kind-deploy-sim.sh
  ```

* **Deploy with Istio Gateway**

  ```bash
  ./kind-deploy-sim.sh --gateway istio
  ```

* **Deploy while Skipping Metrics**

  ```bash
  ./kind-deploy-sim.sh --skip-metrics
  ```

* **Deploy with Istio and Skip Metrics**

  ```bash
  ./kind-deploy-sim.sh --gateway istio --skip-metrics
  ```

-----

## Script Workflow

The script performs the following automated steps:

1.  **Create Cluster**: A `kind` cluster named **llm-d-sim** is created.
2.  **Install Dependencies**: Local dependencies are installed using the `install-deps.sh` script.
3.  **Deploy Infrastructure**: The base infrastructure chart is deployed using the `llmd-infra-installer.sh` script, configuring the specified gateway and metrics options. If `istio` is chosen, a required `DestinationRule` is automatically applied.
4.  **Deploy Workloads**: The simulation workloads from the `examples/sim` directory are deployed via `helmfile`.
5.  **Wait for Pods**: The script waits for all pods in the `llm-d` namespace to become ready.

-----

## Scaling Out Inference Replicas

To scale out a decode or prefill replica, you simply adjust the `llm-d-infra/quickstart/examples/sim/ms-sim/values.yaml` file: 

```yaml
decode:
  create: true
  replicas: 3 # <- adjust this value to the desired replica count
```

Then simply apply the new value from the `llm-d-infra/quickstart/examples/sim` directory with:

```shell
helmfile --selector managedBy=helmfile apply
```

Now you will see the additional decode pod(s):

```shell
kubectl get pods -n llm-d
NAME                                                 READY   STATUS    RESTARTS   AGE
gaie-sim-epp-67666fcfb5-mjskd                        1/1     Running   0          12m
infra-sim-inference-gateway-856ccd85b7-cwwhr         1/1     Running   0          14m
ms-sim-llm-d-modelservice-decode-55d48485f-2brw8     2/2     Running   0          2m52s
ms-sim-llm-d-modelservice-decode-55d48485f-bp2w5     2/2     Running   0          12m
ms-sim-llm-d-modelservice-decode-55d48485f-wpmqc     2/2     Running   0          12m
ms-sim-llm-d-modelservice-prefill-5f4dc68d77-p9xd9   1/1     Running   0          12m
```

You can view what pod completion requests land on by viewing the pod prefix with the following log tailing:

```shell
kubectl logs -n llm-d \
  -l llm-d.ai/role=decode \
  -c vllm \
  --tail=100 \
  --follow \
  --prefix  | grep completion
```

## Manual Installation

If you need to install the components individually or want to understand the deployment process, follow the steps below. These commands mirror the actions performed by the `deploy-kind-dev.sh` script.

-----

### 1. Create the Kind Cluster

First, create the local Kubernetes cluster.

```bash
kind create cluster --name llm-d-sim
```

-----

### 2. Install Dependencies

Navigate to the `quickstart` directory and run the dependency installer.

```bash
cd /path/to/repo/quickstart
./install-deps.sh
```

-----

### 3. Deploy Base Infrastructure

From the `quickstart` directory, run the infrastructure chart installer. Choose your gateway (`kgateway` or `istio`) and optionally disable metrics.

**For `kgateway` (default):**

```bash
HF_TOKEN=dummy ./llmd-infra-installer.sh --namespace llm-d --gateway kgateway --release infra-sim
```

**For `istio` with metrics disabled:**

```bash
HF_TOKEN=dummy ./llmd-infra-installer.sh --namespace llm-d --gateway istio --release infra-sim --disable-metrics-collection
```

-----

### 4. Deploy Simulation Workloads

Navigate to the simulation examples directory and apply the `helmfile` charts.

```bash
cd /path/to/repo/examples/sim
helmfile --selector managedBy=helmfile apply
```

-----

### 5. Apply Istio Fix (If Applicable)

This step is **only** required if you chose `istio` as your gateway in Step 3.

```bash
export EPP_NAMESPACE="llm-d"
export EPP_NAME=$(kubectl get svc -n "${EPP_NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -- "-epp" | head -n1)

cat <<EOF | kubectl apply -n "${EPP_NAMESPACE}" -f -
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ${EPP_NAME}-insecure-tls
spec:
  host: ${EPP_NAME}
  trafficPolicy:
    tls:
      mode: SIMPLE
      insecureSkipVerify: true
EOF
```

-----

### 6. Wait for Pods to be Ready

Finally, wait for all the pods in the `llm-d` namespace to report a `Ready` status.

```bash
kubectl wait --for=condition=ready pod -n llm-d --all --timeout=300s
```

## Cleanup

After you are finished, you can completely remove the cluster with the following:

```bash
kind delete cluster --name llm-d-sim
```
