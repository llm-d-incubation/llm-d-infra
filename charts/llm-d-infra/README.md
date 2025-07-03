
# llm-d Helm Chart

![Version: 1.1.0](https://img.shields.io/badge/Version-1.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

llm-d-infra is a chart containing the infrastructure around llm-d, a Kubernetes-native high-performance distributed LLM inference framework

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| llm-d |  | <https://github.com/llm-d-incubation/llm-d-infra> |

## Source Code

* <https://github.com/llm-d-incubation/llm-d-infra>

---

## TL;DR

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add llm-d https://llm-d.ai/llm-d-deployer

helm install my-llm-d llm-d/llm-d
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
- [Gateway API](https://gateway-api.sigs.k8s.io/guides/) (see for [examples](https://github.com/llm-d/llm-d-deployer/blob/6db03770626f6e67b099300c66bfa535b2504727/chart-dependencies/ci-deps.sh#L22) we use in our CI)
- [kGateway](https://kgateway.dev/) (or [Istio](http://istio.io/)) installed in the cluster (see for [examples](https://github.com/llm-d/llm-d-deployer/blob/6db03770626f6e67b099300c66bfa535b2504727/chart-dependencies/kgateway/install.sh) we use in our CI)

## Usage

Charts are available in the following formats:

- [Chart Repository](https://helm.sh/docs/topics/chart_repository/)
- [OCI Artifacts](https://helm.sh/docs/topics/registries/)

### Installing from the Chart Repository

The following command can be used to add the chart repository:

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add llm-d https://llm-d.ai/llm-d-deployer
```

Once the chart has been added, install this chart. However before doing so, please review the default `values.yaml` and adjust as needed.

```console
helm upgrade -i <release_name> llm-d/llm-d
```

### Installing from an OCI Registry

Charts are also available in OCI format. The list of available releases can be found [here](https://github.com/orgs/llm-d/packages/container/package/llm-d-deployer%2Fllm-d).

Install one of the available versions:

```shell
helm upgrade -i <release_name> oci://ghcr.io/llm-d/llm-d-deployer/llm-d --version=<version>
```

> **Tip**: List all releases using `helm list`

### Testing a Release

Once an Helm Release has been deployed, you can test it using the [`helm test`](https://helm.sh/docs/helm/helm_test/) command:

```sh
helm test <release_name>
```

This will run a simple Pod in the cluster to check that the application deployed is up and running.

You can control whether to disable this test pod or you can also customize the image it leverages.
See the `test.enabled` and `test.image` parameters in the [`values.yaml`](./values.yaml) file.

> **Tip**: Disabling the test pod will not prevent the `helm test` command from passing later on. It will simply report that no test suite is available.

Below are a few examples:

<details>

<summary>Disabling the test pod</summary>

```sh
helm install <release_name> <repo_or_oci_registry> \
  --set test.enabled=false
```

</details>

<details>

<summary>Customizing the test pod image</summary>

```sh
helm install <release_name> <repo_or_oci_registry> \
  --set test.image.repository=curl/curl-base \
  --set test.image.tag=8.11.1
```

</details>

### Uninstalling the Chart

To uninstall/delete the `my-llm-d-release` deployment:

```console
helm uninstall my-llm-d-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Requirements

Kubernetes: `>= 1.30.0-0`

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
| gateway.enabled | Deploy resources related to Gateway | bool | `true` |
| gateway.fullnameOverride | String to fully override gateway.fullname | string | `""` |
| gateway.gatewayClassName | Gateway class that determines the backend used. Currently supported values: "istio", "kgateway", "gke-l7-rilb", or "gke-l7-regional-external-managed" | string | `"istio"` |
| gateway.nameOverride | String to partially override gateway.fullname | string | `""` |
| gateway.serviceType | Gateway's service type. Ingress is only available if the service type is set to NodePort. Accepted values: ["LoadBalancer", "NodePort"] | string | `"NodePort"` |
| ingress | Ingress configuration | object | See below |
| ingress.annotations | Additional annotations for the Ingress resource | object | `{}` |
| ingress.clusterRouterBase | used as part of the host dirivation if not specified from OCP cluster domain (dont edit) | string | `""` |
| ingress.enabled | Deploy Ingress | bool | `true` |
| ingress.extraHosts | List of additional hostnames to be covered with this ingress record (e.g. a CNAME) <!-- E.g. extraHosts:   - name: llm-d.env.example.com     path: / (Optional)     pathType: Prefix (Optional)     port: 7007 (Optional) --> | list | `[]` |
| ingress.extraTls | The TLS configuration for additional hostnames to be covered with this ingress record. <br /> Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls <!-- E.g. extraTls:   - hosts:     - llm-d.env.example.com     secretName: llm-d-env --> | list | `[]` |
| ingress.host | Hostname to be used to expose the NodePort service to the inferencing gateway | string | `""` |
| ingress.ingressClassName | Name of the IngressClass cluster resource which defines which controller will implement the resource (e.g nginx) | string | `""` |
| ingress.path | Path to be used to expose the full route to access the inferencing gateway | string | `"/"` |
| ingress.tls | Ingress TLS parameters | object | `{"enabled":false,"secretName":""}` |
| ingress.tls.enabled | Enable TLS configuration for the host defined at `ingress.host` parameter | bool | `false` |
| ingress.tls.secretName | The name to which the TLS Secret will be called | string | `""` |
| kubeVersion | Override Kubernetes version | string | `""` |
| nameOverride | String to partially override common.names.fullname | string | `""` |
| test | Helm tests | object | `{"enabled":false,"image":{"imagePullPolicy":"Always","pullSecrets":[],"registry":"quay.io","repository":"curl/curl","tag":"latest"}}` |
| test.enabled | Enable rendering of helm test resources | bool | `false` |
| test.image.imagePullPolicy | Specify a imagePullPolicy | string | `"Always"` |
| test.image.pullSecrets | Optionally specify an array of imagePullSecrets (evaluated as templates) | list | `[]` |
| test.image.registry | Test connection pod image registry | string | `"quay.io"` |
| test.image.repository | Test connection pod image repository. Note that the image needs to have both the `sh` and `curl` binaries in it. | string | `"curl/curl"` |
| test.image.tag | Test connection pod image tag. Note that the image needs to have both the `sh` and `curl` binaries in it. | string | `"latest"` |

## Features

This chart deploys all infrastructure required to run the [llm-d](https://llm-d.ai/) project. It includes:

- A Gateway
- A `ModelService` CRD
- A [Model Service controller](https://github.com/llm-d/llm-d-model-service) with full RBAC support
- [Redis](https://github.com/bitnami/charts/tree/main/bitnami/redis) deployment for LMCache and smart routing
- Enabled monitoring and metrics scraping for llm-d components

Once deployed you can create `ModelService` CRs to deploy your models. The model service controller will take care of deploying the models and exposing them through the Gateway.

### Sample Application

By default the chart also deploys a sample application that deploys a Llama model. See `.Values.sampleApplication` in the `values.yaml` file for more details. If you wish to get rid of it, set `sampleApplication.enabled` to `false` in the `values.yaml` file:

```bash
helm upgrade -i <release_name> llm-d/llm-d \
  --set sampleApplication.enabled=false
```

### Metrics collection

There are various metrics exposed by the llm-d components. To enable/disable scraping of these metrics, look for `metrics.enabled` toggles in the `values.yaml` file. By default, all components have metrics enabled.

### Model Service

A new custom resource definition (CRD) called `ModelService` is created by the chart. This CRD is used to deploy models on the cluster. The model service controller will take care of deploying the models.

To see the full spec of the `ModelService` CRD, refer to the [ModelService CRD API reference](https://github.com/llm-d/llm-d-model-service/blob/main/docs/api_reference/out.asciidoc).

A basic example of a `ModelService` CR looks like this:

```yaml
apiVersion: llm-d.ai/v1alpha1
kind: ModelService
metadata:
  name: <name>
spec:
  decoupleScaling: false
  baseConfigMapRef:
    name: basic-gpu-with-nixl-and-redis-lookup-preset
  routing:
    modelName: <model_name>
  modelArtifacts:
    uri: pvc://<pvc_name>/<path_to_model>
  decode:
    replicas: 1
    containers:
    - name: "vllm"
      args:
      - "--model"
      - <model_name>
  prefill:
    replicas: 1
    containers:
    - name: "vllm"
      args:
      - "--model"
      - <model_name>
```

## Quickstart

If you want to get started quickly and experiment with llm-d, you can also take a look at the [Quickstart](https://github.com/llm-d/llm-d-deployer/blob/main/quickstart/README.md) we provide. It wraps this chart and deploys a full llm-d stack with all it's prerequisites a sample application.

## Contributing

We welcome contributions to this chart! If you have any suggestions or improvements, please feel free to open an issue or submit a pull request. Please read our [contributing guide](https://github.com/llm-d/llm-d-deployer/blob/main/CONTRIBUTING.md) on how to submit a pull request.
