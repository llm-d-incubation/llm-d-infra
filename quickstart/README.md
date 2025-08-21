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

The llm-d-infra chart contains all the helm charts necessary to deploy llm-d-infra. To facilitate the installation of the helm charts, the `llmd-infra-installer.sh` script is provided. This script will populate the necessary manifests in the `manifests` directory.

- [inference-scheduling](./examples/inference-scheduling): llm-d-inference-scheduling
- [pd-disaggregation](./examples/pd-disaggregation): llm-d-pd
- [precise-prefix-cache-aware](./examples/precise-prefix-cache-aware): llm-d-wide-ep

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

After executing the install script, you will find that resources are created according to the installation options.

#### Installation with Istio

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

***The Namespace name might differ depending on the installation option.***

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

***The Namespace name might differ depending on the installation option.***

```bash
kubectl get pods,gateway -n llm-d
```

```bash
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/llm-d-infra-inference-gateway-69fd4dcfb9-nzs29   1/1     Running   0          22m

NAME                                                              CLASS      ADDRESS        PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/llm-d-infra-inference-gateway   kgateway   [IP Address]   True         22m
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

llm-d-infra includes support for metrics collection from vLLM pods. llm-d applies PodMonitors to trigger Prometheus
scrape targets when enabled with llm-d-modelservice helm chart values. See [MONITORING.md](MONITORING.md) for details.
In OpenShift, the built-in user workload monitoring Prometheus stack can be utilized to collect metrics.
In Kubernetes, Prometheus and Grafana can be installed from the prometheus-community
[kube-prometheus-stack helm charts](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).

### Uninstall

This will remove llm-d resources from the cluster. This is useful, especially for test/dev if you want to
make a change, simply uninstall and then run the installer again with any changes you make.

```bash
./llmd-infra-installer.sh --uninstall
```
