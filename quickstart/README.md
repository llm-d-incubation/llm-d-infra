# llm-d-infra Quick Start

Getting started with llm-d-infra on Kubernetes.

If you want to deploy llm-d-infra and related tools step by step, see the [README-step-by-step.md](README-step-by-step.md) instructions.

For more information on llm-d, see the llm-d git repository [here](https://github.com/llm-d/llm-d) and website [here](https://llm-d.ai).

## Overview

This guide will walk you through the steps to install and deploy llm-d on a Kubernetes cluster, using an opinionated flow in order to get up and running as quickly as possible.

## Client Configuration

### Get the code

Clone the llm-d-infra repository.

```bash
git clone https://github.com/llm-d-incubation/llm-d-infra.git
```

Navigate to the quickstart directory

```bash
cd llm-d-infra/quickstart
```

### Required tools

Following prerequisite are required for the installer to work.

- [yq (mikefarah) – installation](https://github.com/mikefarah/yq?tab=readme-ov-file#install)
- [jq – download & install guide](https://stedolan.github.io/jq/download/)
- [git – installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Helm – quick-start install](https://helm.sh/docs/intro/install/)
- [Helmfile - installation](https://github.com/helmfile/helmfile?tab=readme-ov-file#installation)
- [Kustomize – official install docs](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [kubectl – install & setup](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

You can use the installer script that installs all the required dependencies.

```bash
./install-deps.sh
```

### Required credentials and configuration

- [llm-d-infra GitHub repo – clone here](https://github.com/llm-d-incubation/llm-d-infra.git)

### Target Platforms

Since the llm-d-infra is based on helm charts, llm-d can be deployed on a variety of Kubernetes platforms. As more platforms are supported, the installer will be updated to support them.

In this instruction, the target is vanilla kubernetes and if you look for other platform's instructions, you could find them from following links.

- [Minikube](docs/infra-providers/minikube/README-minikube.md)
- [OpenShift](docs/infra-providers/openshift/README-openshift.md)
- [OpenShift on AWS (ROSA)](docs/infra-providers/openshift-aws/openshift-aws.md)

## llm-d-infra Installation

Only a single installation of llm-d on a cluster is currently supported.  In the future, multiple model services will be supported.  Until then, [uninstall llm-d](#uninstall) before reinstalling.

The llm-d-infra contains all the helm charts necessary to deploy llm-d-infra. To facilitate the installation of the helm charts, the `llmd-infra-installer.sh` script is provided. This script will populate the necessary manifests in the `manifests` directory.
After this, it will apply all the manifests in order to bring up the cluster.

The llmd-infra-installer.sh script aims to simplify the installation of llm-d using the llm-d-infra as it's main function.  It scripts as many of the steps as possible to make the installation process more streamlined.  This includes:

- Installing the GAIE infrastructure
- Creating the namespace with any special configurations
- Deploying the network stack (istio/kgateway)
- Creating the pull secret to download the images
- Deploying the Gateway

It also supports uninstalling the llm-d infrastructure.

Before proceeding with the installation, ensure you have completed the prerequisites and are able to issue `kubectl` or `oc` commands to your cluster by configuring your `~/.kube/config` file or by using the `oc login` command.

### Usage

The installer needs to be run from the `llm-d-infra/quickstart` directory as a cluster admin with CLI access to the cluster.

```bash
./llmd-infra-installer.sh [OPTIONS]
```

### Flags

| Flag                                 | Description                                                   | Example                                                          |
|--------------------------------------|---------------------------------------------------------------|------------------------------------------------------------------|
| `-n`, `--namespace NAME`             | K8s namespace (default: llm-d)                                | `./llmd-infra-installer.sh --namespace foo`                            |
| `-f`, `--values-file PATH`           | Path to Helm values.yaml file (default: values.yaml)          | `./llmd-infra-installer.sh --values-file /path/to/values.yaml`         |
| `-u`, `--uninstall`                  | Uninstall the llm-d components from the current cluster       | `./llmd-infra-installer.sh --uninstall`                                |
| `-d`, `--debug`                      | Add debug mode to the helm install                            | `./llmd-infra-installer.sh --debug`                                    |
| `-m`, `--disable-metrics-collection` | Disable metrics collection (Prometheus will not be installed) | `./llmd-infra-installer.sh --disable-metrics-collection`               |
| `-k`, `--minikube`                   | Deploy on an existing minikube instance with hostPath storage | `./llmd-infra-installer.sh --minikube`                                 |
| `-g`, `--context`                    | Supply a specific Kubernetes context                          | `./llmd-infra-installer.sh --context`                                  |
| `-j`, `--gateway`                    | Select gateway type (istio, kgateway) (default: istio)        | `./llm-installer.sh --gateway kgateway`                          |
| `-r`, `--release `                   | (Helm) Chart release name                                     | `./llmd-infra-installer.sh --release llm-d-infra`                      |
| `-h`, `--help`                       | Show this help and exit                                       | `./llmd-infra-installer.sh --help`                                     |

## Examples

### Install llm-d on an Existing Kubernetes Cluster

```bash
export HF_TOKEN="your-token"
./llmd-infra-installer.sh
```

### Install on OpenShift

Before running the installer, ensure you have logged into the cluster as a cluster administrator.  For example:

```bash
oc login --token=sha256~yourtoken --server=https://api.yourcluster.com:6443
```

```bash
export HF_TOKEN="your-token"
./llmd-infra-installer.sh
```

### Validation

After executing install script, you can find the resources will be created according to installation option.

#### Installation with istio

- istio-system

```bash
kubectl get pods,svc -n istio-system
```

```bash
NAME                         READY   STATUS    RESTARTS   AGE
pod/istiod-774dfd9b6-wjlm2   1/1     Running   0          3m33s

NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                                 AGE
service/istiod   ClusterIP   [Cluster IP]   <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP   3m33s
```

- llm-d

```bash
kubectl get pods,gateway -n llm-d
```

```bash
NAME                                                      READY   STATUS    RESTARTS   AGE
pod/llm-d-infra-inference-gateway-istio-79b75bb5d-blwgs   1/1     Running   0          87s

NAME                                                              CLASS   ADDRESS                                                       PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/llm-d-infra-inference-gateway   istio   llm-d-infra-inference-gateway-istio.llm-d.svc.cluster.local   True         87s
```

- llm-d-monitoring

```bash
kubectl get pods,gateway -n llm-d-monitoring
```

```bash
NAME                                                         READY   STATUS    RESTARTS   AGE
pod/alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          2m51s
pod/prometheus-grafana-7fbfb5f947-h92zc                      3/3     Running   0          2m51s
pod/prometheus-kube-prometheus-operator-56c5c488db-clslv     1/1     Running   0          2m51s
pod/prometheus-kube-state-metrics-7f5f75c85d-twvj5           1/1     Running   0          2m51s
pod/prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          2m51s
pod/prometheus-prometheus-node-exporter-94jkw                1/1     Running   0          2m51s
pod/prometheus-prometheus-node-exporter-c8fzc                1/1     Running   0          2m51s
pod/prometheus-prometheus-node-exporter-tks77                1/1     Running   0          2m51s
```

#### Installation with kgateway

- kgateway-system

```bash
kubectl get pods -n kgateway-system
```

```bash
NAME                       READY   STATUS    RESTARTS   AGE
kgateway-ddbb7668c-cc9df   1/1     Running   0          25m
```

- llm-d

```bash
kubectl get pods,gateway -n llm-d
```

```bash
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/llm-d-infra-inference-gateway-69fd4dcfb9-nzs29   1/1     Running   0          22m

NAME                                                              CLASS      ADDRESS        PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/llm-d-infra-inference-gateway   kgateway   [External IP]  True         22m
```

- llm-d-monitoring

```bash
kubectl get pods,gateway -n llm-d-monitoring
```

```bash
NAME                                                         READY   STATUS    RESTARTS   AGE
pod/alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          24m
pod/prometheus-grafana-7fbfb5f947-jdb7l                      3/3     Running   0          24m
pod/prometheus-kube-prometheus-operator-56c5c488db-fr9vt     1/1     Running   0          24m
pod/prometheus-kube-state-metrics-7f5f75c85d-2nfwv           1/1     Running   0          24m
pod/prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          24m
pod/prometheus-prometheus-node-exporter-65cbt                1/1     Running   0          24m
pod/prometheus-prometheus-node-exporter-n9n6t                1/1     Running   0          24m
pod/prometheus-prometheus-node-exporter-szjwv                1/1     Running   0          24m
```

### Metrics Collection

llm-d-infra includes built-in support for metrics collection using Prometheus and Grafana. This feature is enabled by default but can be disabled using the
`--disable-metrics-collection` flag during installation. llm-d applies ServiceMonitors for vLLM and inference-gateway services to trigger Prometheus
scrape targets. In OpenShift, the built-in user workload monitoring Prometheus stack can be utilized. In Kubernetes, Prometheus and Grafana are installed from the
prometheus-community [kube-prometheus-stack helm charts](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).

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

#### Security Note

When running in a cloud environment (like EC2), make sure to:

1. Configure your security groups to allow inbound traffic on ports 9090 and 3000 (if using port-forwarding)
2. Use the `--address 0.0.0.0` flag with port-forward to allow external access
3. Consider setting up proper authentication for production environments
4. If using ingress, ensure proper TLS configuration and authentication
5. For OpenShift, consider using the built-in OAuth integration for Grafana

### Uninstall

This will remove llm-d resources from the cluster. This is useful, especially for test/dev if you want to
make a change, simply uninstall and then run the installer again with any changes you make.

```bash
./llmd-infra-installer.sh --uninstall
```
