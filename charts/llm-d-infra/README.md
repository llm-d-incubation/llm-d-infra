# llm-d-infra Helm Chart

![Version: 1.0.5](https://img.shields.io/badge/Version-1.0.5-informational?style=flat-square)
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
- [Gateway API](https://gateway-api.sigs.k8s.io/guides/) (see for [examples](https://github.com/llm-d-incubation/llm-d-infra/blob/main/chart-dependencies/ci-deps.sh#L22) we use in our CI)
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

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| auth.hf_token.enabled | bool | `true` |  |
| auth.hf_token.secretKey | string | `"HF_TOKEN"` |  |
| auth.hf_token.secretName | string | `"llm-d-hf-token"` |  |
| clusterDomain | string | `"cluster.local"` | Default Kubernetes cluster domain |
| common | object | `{}` | Parameters for bitnami.common dependency |
| commonAnnotations | object | `{}` | Annotations to add to all deployed objects |
| commonLabels | object | `{}` | Labels to add to all deployed objects |
| extraDeploy | list | `[]` | Array of extra objects to deploy with the release |
| fullnameOverride | string | `""` | String to fully override common.names.fullname |
| gateway | object | See below | Gateway configuration |
| gateway.annotations | object | `{}` | Additional annotations provided to the Gateway resource |
| gateway.enabled | bool | `true` | Deploy resources related to Gateway |
| gateway.fullnameOverride | string | `""` | String to fully override gateway.fullname |
| gateway.gatewayClassName | string | `"istio"` | Gateway class that determines the backend used Currently supported values: "kgateway" or "istio" |
| gateway.nameOverride | string | `""` | String to partially override gateway.fullname |
| gateway.serviceType | string | `"NodePort"` | Gateway's service type. Ingress is only available if the service type is set to NodePort. Accepted values: ["LoadBalancer", "NodePort"] |
| ingress | object | See below | Ingress configuration |
| ingress.annotations | object | `{}` | Additional annotations for the Ingress resource |
| ingress.clusterRouterBase | string | `""` | used as part of the host dirivation if not specified from OCP cluster domain (dont edit) |
| ingress.enabled | bool | `true` | Deploy Ingress |
| ingress.extraHosts | list | `[]` | List of additional hostnames to be covered with this ingress record (e.g. a CNAME) <!-- E.g. extraHosts:   - name: llm-d.env.example.com     path: / (Optional)     pathType: Prefix (Optional)     port: 7007 (Optional) --> |
| ingress.extraTls | list | `[]` | The TLS configuration for additional hostnames to be covered with this ingress record. <br /> Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls <!-- E.g. extraTls:   - hosts:     - llm-d.env.example.com     secretName: llm-d-env --> |
| ingress.host | string | `""` | Hostname to be used to expose the NodePort service to the inferencing gateway |
| ingress.ingressClassName | string | `""` | Name of the IngressClass cluster resource which defines which controller will implement the resource (e.g nginx) |
| ingress.path | string | `"/"` | Path to be used to expose the full route to access the inferencing gateway |
| ingress.tls | object | `{"enabled":false,"secretName":""}` | Ingress TLS parameters |
| ingress.tls.enabled | bool | `false` | Enable TLS configuration for the host defined at `ingress.host` parameter |
| ingress.tls.secretName | string | `""` | The name to which the TLS Secret will be called |
| kubeVersion | string | `""` | Override Kubernetes version |
| nameOverride | string | `""` | String to partially override common.names.fullname |

## Features

This chart deploys all infrastructure required to run the [llm-d](https://llm-d.ai/) project. It includes:

- A Gateway
- Gateway Parameters if Kgateway is chosen as a provider
- An optional ingress to sit in front of the gateway
# llm-d-infra

![Version: 1.0.5](https://img.shields.io/badge/Version-1.0.5-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1](https://img.shields.io/badge/AppVersion-0.1-informational?style=flat-square)

llm-d-infra are the infrastructure components surrounding the llm-d system - a Kubernetes-native high-performance distributed LLM inference framework

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| llm-d-infra |  | <https://github.com/llm-d-incubation/llm-d-infra> |

## Source Code

* <https://github.com/llm-d-incubation/llm-d-infra>

## Requirements

Kubernetes: `>= 1.28.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | common | 2.27.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| auth.hf_token.enabled | bool | `true` |  |
| auth.hf_token.secretKey | string | `"HF_TOKEN"` |  |
| auth.hf_token.secretName | string | `"llm-d-hf-token"` |  |
| clusterDomain | string | `"cluster.local"` | Default Kubernetes cluster domain |
| common | object | `{}` | Parameters for bitnami.common dependency |
| commonAnnotations | object | `{}` | Annotations to add to all deployed objects |
| commonLabels | object | `{}` | Labels to add to all deployed objects |
| extraDeploy | list | `[]` | Array of extra objects to deploy with the release |
| fullnameOverride | string | `""` | String to fully override common.names.fullname |
| gateway | object | See below | Gateway configuration |
| gateway.annotations | object | `{}` | Additional annotations provided to the Gateway resource |
| gateway.enabled | bool | `true` | Deploy resources related to Gateway |
| gateway.fullnameOverride | string | `""` | String to fully override gateway.fullname |
| gateway.gatewayClassName | string | `"istio"` | Gateway class that determines the backend used Currently supported values: "kgateway" or "istio" |
| gateway.nameOverride | string | `""` | String to partially override gateway.fullname |
| gateway.serviceType | string | `"NodePort"` | Gateway's service type. Ingress is only available if the service type is set to NodePort. Accepted values: ["LoadBalancer", "NodePort"] |
| ingress | object | See below | Ingress configuration |
| ingress.annotations | object | `{}` | Additional annotations for the Ingress resource |
| ingress.clusterRouterBase | string | `""` | used as part of the host dirivation if not specified from OCP cluster domain (dont edit) |
| ingress.enabled | bool | `true` | Deploy Ingress |
| ingress.extraHosts | list | `[]` | List of additional hostnames to be covered with this ingress record (e.g. a CNAME) <!-- E.g. extraHosts:   - name: llm-d.env.example.com     path: / (Optional)     pathType: Prefix (Optional)     port: 7007 (Optional) --> |
| ingress.extraTls | list | `[]` | The TLS configuration for additional hostnames to be covered with this ingress record. <br /> Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls <!-- E.g. extraTls:   - hosts:     - llm-d.env.example.com     secretName: llm-d-env --> |
| ingress.host | string | `""` | Hostname to be used to expose the NodePort service to the inferencing gateway |
| ingress.ingressClassName | string | `""` | Name of the IngressClass cluster resource which defines which controller will implement the resource (e.g nginx) |
| ingress.path | string | `"/"` | Path to be used to expose the full route to access the inferencing gateway |
| ingress.tls | object | `{"enabled":false,"secretName":""}` | Ingress TLS parameters |
| ingress.tls.enabled | bool | `false` | Enable TLS configuration for the host defined at `ingress.host` parameter |
| ingress.tls.secretName | string | `""` | The name to which the TLS Secret will be called |
| kubeVersion | string | `""` | Override Kubernetes version |
| nameOverride | string | `""` | String to partially override common.names.fullname |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
