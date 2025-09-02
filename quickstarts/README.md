# llm-d-infra Quick Start

This document is meant to guide users through the process of using, deploying and potentially customizing a quickstart. The source of truth for installing a given quickstart will always live that particular directory, this guide is mean to walk through the common steps, and educate users on decisions that happen at each of those phases.

## Overview

This guide will walk you through the steps to install and deploy llm-d on a Kubernetes cluster, using an opinionated flow in order to get up and running as quickly as possible.

## Prerequisites

### Tool Dependencies

You will need to install some dependencies (like helm, yq, git, etc.) and have a HuggingFace token for most examples. We have documented these requirements and instructions in the [dependencies directory](./dependencies/README.md). To install the dependencies, use the provided [install-deps.sh](./dependencies/install-deps.sh) script.

### HuggingFace Token

A HuggingFace token is required to download models from the HuggingFace Hub. You must create a Kubernetes secret containing your HuggingFace token in the target namespace before deployment, see [instructions](./dependencies/README.md#huggingface-token).

### Gateway Control Plane

Additionally, it is assumed you have configured and deployed your Gateway Control Plane and their prerequisite CRDs. For information on this, see the [gateway-control-plane-providers](./gateway-control-plane-providers/README.md).

### Target Platforms

Since the llm-d-infra is based on helm charts, llm-d can be deployed on a variety of Kubernetes platforms. Requirements, workarounds, and any other documentation relevant to these platforms will live in the [infra-providers directory](./docs/infra-providers/).

## llm-d-infra Installation

The llm-d-infra repository provides Helm charts to deploy various llm-d components. To install a specific component, navigate to its example directory and follow the instructions in its README:

- [inference-scheduling](./examples/inference-scheduling/README.md): Inference scheduling
- [pd-disaggregation](./examples/pd-disaggregation/README.md): PD disaggregated deployment
- [precise-prefix-cache-aware](./examples/precise-prefix-cache-aware/README.md): Precise prefix cache
- [wide-ep-lws](./examples/wide-ep-lws/README.md): Wide EP LWS
- [sim](./examples/sim/README.md): vLLM simulator

### Install llm-d on an Existing Kubernetes Cluster

To install llm-d components, navigate to the desired example directory and follow its README instructions. For example:

```bash
cd examples/inference-scheduling  # Navigate to your desired example directory
# Follow the README.md instructions in the example directory
```

### Install on OpenShift

Before running any installation, ensure you have logged into the cluster as a cluster administrator. For example:

```bash
oc login --token=sha256~yourtoken --server=https://api.yourcluster.com:6443
```

After logging in, follow the same steps as described in the "Install llm-d on an Existing Kubernetes Cluster" section above.

### Validation

After executing the install steps from the specific example README, you will find that resources are created according to the installation options.

First, you should be able to list all Helm releases to view the charts installed into your chosen namespace:

```bash
helm list -n ${NAMESPACE}
```

Out of the box with this example, you should have the following resources:

```bash
kubectl get all -n ${NAMESPACE}
```

**Note:** This assumes no other quickstart deployments in your given `${NAMESPACE}`.

### Using the Stack

For instructions on getting started with making inference requests, see [getting-started-inferencing.md](./docs/getting-started-inferencing.md).

### Metrics Collection

llm-d-infra includes support for metrics collection from vLLM pods. llm-d applies PodMonitors to trigger Prometheus
scrape targets when enabled with llm-d-modelservice helm chart values. See [MONITORING.md](MONITORING.md) for details.
In OpenShift, the built-in user workload monitoring Prometheus stack can be utilized to collect metrics.
In Kubernetes, Prometheus and Grafana can be installed from the prometheus-community
[kube-prometheus-stack helm charts](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).

### Uninstall

To remove llm-d resources from the cluster, refer to the uninstallation instructions in the specific example's README that you installed.
