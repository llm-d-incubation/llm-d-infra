# llm-d Quick Start

Getting Started with llm-d on Kubernetes.  For specific instructions on how to install llm-d on minikube, see the [README-minikube.md](README-minikube.md) instructions.

For more information on llm-d, see the llm-d git repository [here](https://github.com/llm-d/llm-d) and website [here](https://llm-d.ai).

## Overview

This guide will walk you through the steps to install and deploy llm-d on a Kubernetes cluster, using an opinionated flow in order to get up and running as quickly as possible.

## Client Configuration

### Get the code

Clone the llm-d-deployer repository.

```bash
git clone https://github.com/llm-d/llm-d-deployer.git
```

Navigate to the quickstart directory

```bash
cd llm-d-deployer/quickstart
```

### Required tools

Following prerequisite are required for the installer to work.

- [yq (mikefarah) – installation](https://github.com/mikefarah/yq?tab=readme-ov-file#install)
- [jq – download & install guide](https://stedolan.github.io/jq/download/)
- [git – installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Helm – quick-start install](https://helm.sh/docs/intro/install/)
- [Kustomize – official install docs](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [kubectl – install & setup](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

You can use the installer script that installs all the required dependencies.

```bash
./install-deps.sh
```

### Required credentials and configuration

- [llm-d-deployer GitHub repo – clone here](https://github.com/llm-d/llm-d-deployer.git)
- [HuggingFace HF_TOKEN](https://huggingface.co/docs/hub/en/security-tokens) with download access for the model you want to use.  By default the sample application will use [meta-llama/Llama-3.2-3B-Instruct](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct).

> ⚠️ Your Hugging Face account must have access to the model you want to use.  You may need to visit Hugging Face [meta-llama/Llama-3.2-3B-Instruct](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct) and
> accept the usage terms if you have not already done so.

### Target Platforms

Since the llm-d-deployer is based on helm charts, llm-d can be deployed on a variety of Kubernetes platforms. As more platforms are supported, the installer will be updated to support them.

Documentation for example cluster setups are provided in the [infra](./infra) directory.

- [OpenShift on AWS](./infra/openshift-aws.md)

#### Minikube

This can be run on a minimum ec2 node type [g6e.12xlarge](https://aws.amazon.com/ec2/instance-types/g6e/) (4xL40S 48GB but only 2 are used by default) to infer the model meta-llama/Llama-3.2-3B-Instruct that will get spun up.

> ⚠️ If your cluster has no available GPUs, the **prefill** and **decode** pods will remain in **Pending** state.

Verify you have properly installed the container toolkit with the runtime of your choice.

```bash
# Podman
podman run --rm --security-opt=label=disable --device=nvidia.com/gpu=all ubuntu nvidia-smi
# Docker
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

#### OpenShift

- OpenShift - This quickstart was tested on OpenShift 4.17. Older versions may work but have not been tested.
- NVIDIA GPU Operator and NFD Operator - The installation instructions can be found [here](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/steps-overview.html).
- NO Service Mesh or Istio installation as Istio CRDs will conflict with the gateway
- Cluster administrator privileges are required to install the llm-d cluster scoped resources

## llm-d Installation

Only a single installation of llm-d on a cluster is currently supported.  In the future, multiple model services will be supported.  Until then, [uninstall llm-d](#uninstall) before reinstalling.

The llm-d-deployer contains all the helm charts necessary to deploy llm-d. To facilitate the installation of the helm charts, the `llmd-installer.sh` script is provided. This script will populate the necessary manifests in the `manifests` directory.
After this, it will apply all the manifests in order to bring up the cluster.

The llmd-installer.sh script aims to simplify the installation of llm-d using the llm-d-deployer as it's main function.  It scripts as many of the steps as possible to make the installation process more streamlined.  This includes:

- Installing the GAIE infrastructure
- Creating the namespace with any special configurations
- Creating the pull secret to download the images
- Creating the model service CRDs
- Applying the helm charts
- Deploying the sample app (model service)

It also supports uninstalling the llm-d infrastructure and the sample app.

Before proceeding with the installation, ensure you have completed the prerequisites and are able to issue `kubectl` or `oc` commands to your cluster by configuring your `~/.kube/config` file or by using the `oc login` command.

### Usage

The installer needs to be run from the `llm-d-deployer/quickstart` directory as a cluster admin with CLI access to the cluster.

```bash
./llmd-installer.sh [OPTIONS]
```

### Flags

| Flag                                 | Description                                                   | Example                                                          |
|--------------------------------------|---------------------------------------------------------------|------------------------------------------------------------------|
| `-z`, `--storage-size SIZE`          | Size of storage volume                                        | `./llmd-installer.sh --storage-size 15Gi`                        |
| `-c`, `--storage-class CLASS`        | Storage class to use (default: efs-sc)                        | `./llmd-installer.sh --storage-class ocs-storagecluster-cephfs`  |
| `-n`, `--namespace NAME`             | K8s namespace (default: llm-d)                                | `./llmd-installer.sh --namespace foo`                            |
| `-f`, `--values-file PATH`           | Path to Helm values.yaml file (default: values.yaml)          | `./llmd-installer.sh --values-file /path/to/values.yaml`         |
| `-u`, `--uninstall`                  | Uninstall the llm-d components from the current cluster       | `./llmd-installer.sh --uninstall`                                |
| `-d`, `--debug`                      | Add debug mode to the helm install                            | `./llmd-installer.sh --debug`                                    |
| `-i`, `--skip-infra`                 | Skip the infrastructure components of the installation        | `./llmd-installer.sh --skip-infra`                               |
| `-t`, `--download-timeout`           | Timeout for model download job                                | `./llmd-installer.sh --download-timeout`                         |
| `-D`, `--download-model`             | Download the model to PVC from Hugging Face                   | `./llmd-installer.sh --download-model`                           |
| `-m`, `--disable-metrics-collection` | Disable metrics collection (Prometheus will not be installed) | `./llmd-installer.sh --disable-metrics-collection`               |
| `-j`, `--gateway`                    | Select gateway type (istio, kgateway, gke-l7-rilb, gke-l7-regional-external-managed) (default: istio) | `./llm-installer.sh --gateway gke-l7-rilb`                      |
| `-h`, `--help`                       | Show this help and exit                                       | `./llmd-installer.sh --help`                                     |

## Examples

### Install llm-d on an Existing Kubernetes Cluster

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh
```

### Install on OpenShift

Before running the installer, ensure you have logged into the cluster as a cluster administrator.  For example:

```bash
oc login --token=sha256~yourtoken --server=https://api.yourcluster.com:6443
```

```bash
export HF_TOKEN="your-token"
./llmd-installer.sh
```

### Validation

The inference-gateway serves as the HTTP ingress point for all inference requests in our deployment.
It’s implemented as a Kubernetes Gateway (`gateway.networking.k8s.io/v1`) using either kgateway or istio as the
gatewayClassName, and sits in front of your inference pods to handle path-based routing, load balancing, retries,
and metrics. This example validates that the gateway itself is routing your completion requests correctly.
You can execute the [`test-request.sh`](test-request.sh) script to test on the cluster.

```bash
# Default options (the model id will be discovered via /v1/models)
./test-request.sh

# Non-default namespace/model
./test-request.sh -n <NAMESPACE> -m <FULL_MODEL_NAME> --minikube
```

> If you receive an error indicating PodSecurity "restricted" violations when running the smoke-test script, you
> need to remove the restrictive PodSecurity labels from the namespace. Once these labels are removed, re-run the
> script and it should proceed without PodSecurity errors.
> Run the following command:

```bash
kubectl label namespace <NAMESPACE> \
  pod-security.kubernetes.io/warn- \
  pod-security.kubernetes.io/warn-version- \
  pod-security.kubernetes.io/audit- \
  pod-security.kubernetes.io/audit-version-
```

### Customizing your deployment

The helm charts can be customized by modifying the [values.yaml](../charts/llm-d-infra/values.yaml) file.  However, it is recommended to override values in the `values.yaml` by creating a custom yaml file and passing it to the installer using the `--values-file` flag.
Several examples are provided in the [examples](./examples) directory.  You would invoke the installer with the following command:

```bash
./llmd-installer.sh --values-file ./examples/base.yaml
```

These files are designed to be used as a starting point to customize your deployment.  Refer to the [values.yaml](../charts/llm-d-infra/values.yaml) file for all the possible options.

#### Sample Application and Model Configuration

Some of the more common options for changing the sample application model are:

- `sampleApplication.model.modelArtifactURI` - The URI of the model to use.  This is the path to the model either to Hugging Face (`hf://meta-llama/Llama-3.2-3B-Instruct`) or a persistent volume claim (PVC) (`pvc://model-pvc/meta-llama/Llama-3.2-1B-Instruct`).  Using a PVC can be paired with the `--download-model` flag to download the model to PVC.
- `sampleApplication.model.modelName` - The name of the model to use.  This will be used in the naming of deployed resources and also the model ID when using the API.
- `sampleApplication.baseConfigMapRefName` - The name of the preset base configuration to use.  This will depend on the features you want to enable.
- `sampleApplication.prefill.replicas` - The number of prefill replicas to deploy.
- `sampleApplication.decode.replicas` - The number of decode replicas to deploy.

```yaml
sampleApplication:
  model:
    modelArtifactURI: hf://meta-llama/Llama-3.2-1B-Instruct
    modelName: "llama3-1B"
  baseConfigMapRefName: basic-gpu-with-nixl-and-redis-lookup-preset
  prefill:
    replicas: 1
  decode:
    replicas: 1
```

#### Feature Flags

`redis.enabled` - Whether to enable Redis needed to enable the KV Cache Aware Scorer
`modelservice.epp.defaultEnvVarsOverride` - The environment variables to override for the model service.  For each feature flag, you can set the value to `true` or `false` to enable or disable the feature.

```yaml
redis:
  enabled: true
modelservice:
  epp:
    defaultEnvVarsOverride:
      - name: ENABLE_KVCACHE_AWARE_SCORER
        value: "false"
      - name: ENABLE_PREFIX_AWARE_SCORER
        value: "true"
      - name: ENABLE_LOAD_AWARE_SCORER
        value: "true"
      - name: ENABLE_SESSION_AWARE_SCORER
        value: "false"
      - name: PD_ENABLED
        value: "false"
      - name: PD_PROMPT_LEN_THRESHOLD
        value: "10"
      - name: PREFILL_ENABLE_KVCACHE_AWARE_SCORER
        value: "false"
      - name: PREFILL_ENABLE_LOAD_AWARE_SCORER
        value: "false"
      - name: PREFILL_ENABLE_PREFIX_AWARE_SCORER
        value: "false"
      - name: PREFILL_ENABLE_SESSION_AWARE_SCORER
        value: "false"
```

### Metrics Collection

llm-d includes built-in support for metrics collection using Prometheus and Grafana. This feature is enabled by default but can be disabled using the
`--disable-metrics-collection` flag during installation. llm-d applies ServiceMonitors for vLLM and inference-gateway services to trigger Prometheus
scrape targets. In OpenShift, the built-in user workload monitoring Prometheus stack can be utilized. In Kubernetes, Prometheus and Grafana are installed from the
prometheus-community [kube-prometheus-stack helm charts](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).
The [llm-d metrics overview](./metrics-overview.md) lists the metrics scraped with a default llm-d install.

#### Accessing the Metrics UIs

If running on OpenShift, skip to [OpenShift and Grafana](#openshift-and-grafana).

#### Port Forwarding

- Prometheus (port 9090):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-kube-prometheus-prometheus 9090:9090
```

- Grafana (port 3000):

```bash
kubectl port-forward -n llm-d-monitoring --address 0.0.0.0 svc/prometheus-grafana 3000:80
```

Access the User Interfaces at:

- Prometheus: <http://YOUR_IP:9090>
- Grafana: <http://YOUR_IP:3000> (default credentials: admin/admin)

#### Grafana Dashboards

Import the [llm-d dashboard](./grafana/dashboards/llm-d-dashboard.json) from the Grafana UI. Go to `Dashboards -> New -> Import`.
Similarly, import the [inference-gateway dashboard](https://github.com/kubernetes-sigs/gateway-api-inference-extension/blob/main/tools/dashboards/inference_gateway.json)
from the gateway-api-inference-extension repository. Or, if the Grafana Operator is installed in your environment, you might follow the [Grafana setup guide](./grafana-setup.md)
to install the dashboards as `GrafanaDashboard` custom resources.

#### OpenShift and Grafana

If running on OpenShift with user workload monitoring enabled, you can access the metrics through the OpenShift console:

1. Navigate to the OpenShift console
2. In the left navigation bar, click on "Observe"
3. You can access:
   - Metrics: Click on "Metrics" to view and query metrics using the built-in Prometheus UI
   - Targets: Click on "Targets" to see all monitored endpoints and their status

The metrics are automatically integrated into the OpenShift monitoring stack. The llm-d-deployer does not install Grafana on OpenShift,
but it's recommended that users install Grafana to view metrics and import dashboards.

Follow the [Grafana setup guide](./grafana-setup.md).
The guide includes manifests to install the following:

- Grafana instance
- Grafana Prometheus datasource from user workload monitoring stack
- Grafana llm-d dashboard

#### Security Note

When running in a cloud environment (like EC2), make sure to:

1. Configure your security groups to allow inbound traffic on ports 9090 and 3000 (if using port-forwarding)
2. Use the `--address 0.0.0.0` flag with port-forward to allow external access
3. Consider setting up proper authentication for production environments
4. If using ingress, ensure proper TLS configuration and authentication
5. For OpenShift, consider using the built-in OAuth integration for Grafana

### Troubleshooting

The various images can take some time to download depending on your connectivity. Watching events
and logs of the prefill and decode pods is a good place to start. Here are some examples to help
you get started.

```bash
# View the status of the pods in the default llm-d namespace. Replace "llm-d" if you used a custom namespace on install
kubectl get pods -n llm-d

# Describe all prefill pods:
kubectl describe pods -l llm-d.ai/role=prefill -n llm-d

# Fetch logs from each prefill pod:
kubectl logs -l llm-d.ai/role=prefill --all-containers=true -n llm-d --tail=200

# Describe all decode pods:
kubectl describe pods -l llm-d.ai/role=decode -n llm-d

# Fetch logs from each decode pod:
kubectl logs -l llm-d.ai/role=decode --all-containers=true -n llm-d --tail=200

# Describe all endpoint-picker pods:
kubectl describe pod -n llm-d -l llm-d.ai/epp

# Fetch logs from each endpoint-picker pod:
kubectl logs -n llm-d -l llm-d.ai/epp --all-containers=true --tail=200
```

More examples of debugging logs can be found [here](examples/no-features/README.md).

### Uninstall

This will remove llm-d resources from the cluster. This is useful, especially for test/dev if you want to
make a change, simply uninstall and then run the installer again with any changes you make.

```bash
./llmd-installer.sh --uninstall
```
