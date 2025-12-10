
# llm-d-infra Helm Chart

![Version: v1.3.5](https://img.shields.io/badge/Version-v1.3.5-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

llm-d-infra are the infrastructure components surrounding the llm-d system - a Kubernetes-native high-performance distributed LLM inference framework

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| llm-d-infra |  | <https://github.com/llm-d-incubation/llm-d-infra> |

## Source Code

* <https://github.com/llm-d-incubation/llm-d-infra>

---

## TL;DR

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add llm-d-infra https://llm-d-incubation.github.io/llm-d-infra/

helm install my-llm-d-infra llm-d-infra/llm-d-infra
```

## Prerequisites

- Git (v2.25 or [latest](https://github.com/git-guides/install-git#install-git-on-linux), for sparse-checkout support)
- Kubectl (1.25+ or [latest](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) with built-in kustomize support)

```shell
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

- Kubernetes 1.30+ (OpenShift 4.17+)
- Helm 3.10+ or [latest release](https://github.com/helm/helm/releases)
- [Gateway API v1.3.0](https://gateway-api.sigs.k8s.io/guides/) or [latest release](https://github.com/kubernetes-sigs/gateway-api/releases)
- [kGateway](https://kgateway.dev/) (or [Istio](http://istio.io/)) installed in the cluster (see for [examples](https://github.com/llm-d-incubation/llm-d-infra/blob/main/chart-dependencies/kgateway/install.sh) we use in our CI)

## Usage

Charts are available in the following formats:

- [Chart Repository](https://helm.sh/docs/topics/chart_repository/)
- [OCI Artifacts](https://helm.sh/docs/topics/registries/)

### Installing from the Chart Repository

The following command can be used to add the chart repository:

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add llm-d-infra https://llm-d-incubation.github.io/llm-d-infra/
```

Once the chart has been added, install this chart. However before doing so, please review the default `values.yaml` and adjust as needed.

```console
helm upgrade -i <release_name> llm-d-infra/llm-d-infra
```

### Installing from an OCI Registry

Charts are also available in OCI format. The list of available releases can be found [here](https://github.com/orgs/llm-d/packages/container/package/llm-d-infra%2Fllm-d).

Install one of the available versions:

```shell
helm upgrade -i <release_name> oci://ghcr.io/llm-d-incubation/llm-d-infra/llm-d-infra --version=<version>
```

> **Tip**: List all releases using `helm list`

### Uninstalling the Chart

To uninstall/delete the `my-llm-d-infra-release` deployment:

```console
helm uninstall my-llm-d-infra-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Requirements

Kubernetes: `>= 1.28.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | common | 2.27.0 |

## Values

| Key | Description | Type | Default |
|-----|-------------|------|---------|
| clusterDomain | Default Kubernetes cluster domain | string | `"cluster.local"` |
| common | Parameters for bitnami.common dependency | object | `{}` |
| commonAnnotations | Annotations to add to all deployed objects | object | `{}` |
| commonLabels | Labels to add to all deployed objects | object | `{}` |
| extraDeploy | Array of extra objects to deploy with the release | list | `[]` |
| fullnameOverride | String to fully override common.names.fullname | string | `""` |
| gateway | Gateway configuration | object | See below |
| gateway.annotations | Additional annotations provided to the Gateway resource | object | `{}` |
| gateway.destinationRule | see: https://istio.io/latest/docs/reference/config/networking/destination-rule/ | object | `{"enabled":false,"exportTo":[],"host":"localhost","subsets":[],"trafficPolicy":{},"workloadSelector":{}}` |
| gateway.enabled | Deploy resources related to Gateway | bool | `true` |
| gateway.fullnameOverride | String to fully override gateway.fullname | string | `""` |
| gateway.gatewayClassName | Gateway class that determines the backend used Currently supported values: "kgateway", "istio", or "gke-l7-regional-external-managed" | string | `"istio"` |
| gateway.gatewayParameters.resources | Resource requests/limits <br /> Ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-requests-and-limits-of-pod-and-container | object | `{"limits":{"cpu":"2","memory":"1Gi"},"requests":{"cpu":"100m","memory":"128Mi"}}` |
| gateway.labels | Additional labels provided to the Gateway resource | object | `{}` |
| gateway.listeners | Set of listeners exposed via the Gateway, also propagated to the Ingress if enabled | list | `[{"allowedRoutes":{"namespaces":{"from":"All"}},"name":"default","port":80,"protocol":"HTTP"}]` |
| gateway.nameOverride | String to partially override gateway.fullname | string | `""` |
| ingress | Ingress configuration | object | See below |
| ingress.annotations | Additional annotations for the Ingress resource | object | `{}` |
| ingress.enabled | Deploy Ingress (service type must also be ClusterIP) | bool | `false` |
| ingress.extraHosts | List of additional hostnames to be covered with this ingress record (e.g. a CNAME) <!-- E.g. extraHosts:   - name: llm-d.env.example.com     path: / (Optional)     pathType: Prefix (Optional)     port: 7007 (Optional) --> | list | `[]` |
| ingress.extraTls | The TLS configuration for additional hostnames to be covered with this ingress record. <br /> Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls <!-- E.g. extraTls:   - hosts:     - llm-d.env.example.com     secretName: llm-d-env --> | list | `[]` |
| ingress.host | Hostname to be used to expose the ClusterIP service to the inferencing gateway | string | `""` |
| ingress.ingressClassName | Name of the IngressClass cluster resource which defines which controller will implement the resource (e.g nginx) | string | `""` |
| ingress.path | Path to be used to expose the full route to access the inferencing gateway | string | `"/"` |
| ingress.tls | Ingress TLS parameters | object | `{"enabled":false,"secretName":""}` |
| ingress.tls.enabled | Enable TLS configuration for the host defined at `ingress.host` parameter | bool | `false` |
| ingress.tls.secretName | The name to which the TLS Secret will be called | string | `""` |
| kubeVersion | Override Kubernetes version | string | `""` |
| nameOverride | String to partially override common.names.fullname | string | `""` |

## Features

This chart deploys all infrastructure required to run the [llm-d](https://llm-d.ai/) project. It includes:

- A Gateway
- Gateway Parameters if Kgateway is chosen as a provider
- An optional ingress to sit in front of the gateway
