# Well-lit Path: P/D Disaggregation

## Overview

- This example demonstrates how to deploy Llama-70B using vLLM's P/D disaggregation support with NIXL
- This "path" has been validated on an 8xH200 cluster with InfiniBand networking

> WARNING: We are still investigating and optimizing performance for other hardware and networking configurations

In this example, we will demonstrate a deployment of `Llama-3.3-70B-Instruct-FP8` with:

- 4 TP=1 Prefill Workers
- 1 TP=4 Decode Worker

## P/D Best Practices

P/D disaggregation can benefit overall throughput by:

- Specializing P and D workers for compute-bound vs latency-bound workloads
- Reducing the number of copies of the model (increasing KV cache RAM) with wide parallelism

However, P/D disaggregation is not a target for all workloads. We suggest exploring P/D disaggregation for workloads with:

- Large models (e.g. Llama-70B+, not Llama-8B)
- Longer input sequence lengths (e.g 10k ISL | 1k OSL, not 200 ISL | 200 OSL)
- Sparse MoE architectures with opportunities for wide-EP

As a result, as you tune your P/D deployments, we suggest focusing on the following parameters:

- **Heterogeneous Parallelism**: deploy P workers with less parallelism and more replicas and D workers with more parallelism and fewer replicas
- **xPyD Ratios**: tuning the ratio of P workers to D workers to ensure balance for your ISL|OSL ratio

## Hardware Requirements

**Standard Deployment:**
This quickstart expects 8 Nvidia GPUs of any kind, and infiniband.

**Intel XPU Deployment:**
This quickstart can also be deployed on Intel XPU with 4 Intel Data Center GPU Max devices. The Intel XPU configuration uses DeepSeek-R1-Distill-Qwen-1.5B model instead of Llama-70B for compatibility and resource optimization.

## Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. To see what those tools are and minimum versions, check [our docs](../../dependencies/README.md#required-tools), and to install them, see our [install-deps.sh](../../dependencies/install-deps.sh) script.

- You must have the secret containing a HuggingFace Token in the namespace you want to deploy to with key `HF_TOKEN` (see [instructions](../../dependencies/README.md#huggingface-token)).

- Additionally, it is assumed you have configured and deployed your Gateway Control Plane, and their pre-requisite CRDs. For information on this see the [gateway-control-plane-providers](../../gateway-control-plane-providers/) directory.

- **For Intel XPU deployments**: You must have the Intel GPU Plugin deployed on your cluster. The plugin provides the `gpu.intel.com/i915` resource that the Intel XPU workloads require. 
  
  To deploy the Intel GPU Plugin:
  ```bash
  kubectl apply -k 'https://github.com/intel/intel-device-plugins-for-kubernetes/deployments/gpu_plugin?ref=v0.32.1'
  ```
  
  You can verify it's installed by running `kubectl get nodes -o yaml | grep gpu.intel.com/i915` or check that Intel GPU plugin pods are running with `kubectl get pods -n kube-system | grep intel-gpu`.

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-pd` in this example.

```bash
export NAMESPACE=llm-d-pd # Or any namespace your heart desires
cd quickstart/examples/pd-disaggregation
helmfile apply -n ${NAMESPACE}
```

**For Intel XPU deployment:**
```bash
export NAMESPACE=llm-d-pd # shorter namespace recommended to avoid hostname length issues
export RELEASE_NAME_POSTFIX=pd
cd quickstart/examples/pd-disaggregation
helmfile apply -e xpu -n ${NAMESPACE}
```

**_NOTE:_** You can set the `$RELEASE_NAME_POSTFIX` env variable to change the release names. This is how we support concurrent installs. Ex: `RELEASE_NAME_POSTFIX=pd-2 helmfile apply -n ${NAMESPACE}`

**_IMPORTANT:_** When using long namespace names (like `llm-d-pd-disaggregation`), the generated pod hostnames may become too long and cause issues with Intel XPU deployments due to Linux hostname length limitations (typically 64 characters maximum). It's recommended to use shorter namespace names (like `llm-d-pd`) and set `RELEASE_NAME_POSTFIX` to generate shorter hostnames and avoid potential networking or vLLM startup problems.

**_NOTE:_** This uses Istio as the default provider, see [Gateway Options](./README.md#gateway-options) for installing with a specific provider.

### Gateway options

To specify your gateway choice you can use the `-e <gateway option>` flag, ex:

```bash
helmfile apply -e kgateway -n ${NAMESPACE}
```

To see what gateway options are supported refer to our [gateway control plane docs](../../gateway-control-plane-providers/README.md#supported-providers). Gateway configurations per provider are tracked in the [gateway-configurations directory](../common/gateway-configurations/).

You can also customize your gateway, for more information on how to do that see our [gateway customization docs](../../docs/customizing-your-gateway.md).

#### GKE and Intel XPU specific workarounds

While this example out of the box requires Infiniband RDMA, GKE and Intel XPU deployments do not support this. Therefore we patch out these values in [the helmfile](./helmfile.yaml.gotmpl#L73-80) for GKE environments and [the helmfile](./helmfile.yaml.gotmpl#L81-96) for Intel XPU environments.

### Install HTTPRoute

Follow provider specific instructions for installing HTTPRoute.

#### Install for "kgateway" or "istio"

```bash
kubectl apply -f httproute.yaml
```

#### Install for "gke"

```bash
kubectl apply -f httproute.gke.yaml
```

## Verify the Installation

- Firstly, you should be able to list all helm releases to view the 3 charts got installed into your chosen namespace:

```bash
helm list -n ${NAMESPACE}
NAME        NAMESPACE   REVISION    UPDATED                                 STATUS      CHART                       APP VERSION
gaie-pd     llm-d-pd    1           2025-08-24 12:54:51.231537 -0700 PDT    deployed    inferencepool-v0.5.1        v0.5.1
infra-pd    llm-d-pd    1           2025-08-24 12:54:46.983361 -0700 PDT    deployed    llm-d-infra-v1.2.4          v0.2.0
ms-pd       llm-d-pd    1           2025-08-24 12:54:56.736873 -0700 PDT    deployed    llm-d-modelservice-v0.2.7   v0.2.0
```

- Out of the box with this example you should have the following resources:

```bash
kubectl get all -n ${NAMESPACE}
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/gaie-pd-epp-54444ddc66-qv6ds                        1/1     Running   0          2m35s
pod/infra-pd-inference-gateway-istio-56d66db57f-zwtzn   1/1     Running   0          2m41s
pod/ms-pd-llm-d-modelservice-decode-84bf6d5bdd-jzfjn    2/2     Running   0          2m30s
pod/ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-8kfb8   1/1     Running   0          2m30s
pod/ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-g6wmp   1/1     Running   0          2m30s
pod/ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-jx2w2   1/1     Running   0          2m30s
pod/ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-vzcb8   1/1     Running   0          2m30s

NAME                                       TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                        AGE
service/gaie-pd-epp                        ClusterIP      10.16.0.255   <none>        9002/TCP,9090/TCP              2m35s
service/gaie-pd-ip-bb618139                ClusterIP      None          <none>        54321/TCP                      2m35s
service/infra-pd-inference-gateway-istio   LoadBalancer   10.16.3.74    10.16.4.3     15021:31707/TCP,80:34096/TCP   2m41s

NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/gaie-pd-epp                        1/1     1            1           2m36s
deployment.apps/infra-pd-inference-gateway-istio   1/1     1            1           2m42s
deployment.apps/ms-pd-llm-d-modelservice-decode    1/1     1            1           2m31s
deployment.apps/ms-pd-llm-d-modelservice-prefill   4/4     4            4           2m31s

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/gaie-pd-epp-54444ddc66                        1         1         1       2m36s
replicaset.apps/infra-pd-inference-gateway-istio-56d66db57f   1         1         1       2m42s
replicaset.apps/ms-pd-llm-d-modelservice-decode-84bf6d5bdd    1         1         1       2m31s
replicaset.apps/ms-pd-llm-d-modelservice-prefill-86f6fb7cdc   4         4         4       2m31s
```

**_NOTE:_** This assumes no other quickstart deployments in your given `${NAMESPACE}` and you have not changed the default release names via the `${RELEASE_NAME}` environment variable.

## Using the stack

For instructions on getting started making inference requests see [our docs](../../docs/getting-started-inferencing.md)

## Cleanup

To remove the deployment:

```bash
# Remove the model services
helmfile destroy -n ${NAMESPACE}

# Remove the infrastructure
helm uninstall ms-pd -n ${NAMESPACE}
helm uninstall gaie-pd -n ${NAMESPACE}
helm uninstall infra-pd -n ${NAMESPACE}
```

**_NOTE:_** If you set the `$RELEASE_NAME_POSTFIX` environment variable, your release names will be different from the command above: `infra-$RELEASE_NAME_POSTFIX`, `gaie-$RELEASE_NAME_POSTFIX` and `ms-$RELEASE_NAME_POSTFIX`.

**_NOTE:_** You do not need to specify your `environment` with the `-e <environment>` flag to `helmfile` for removing a installation of the quickstart, even if you use a non-default option. You do, however, have to set the `-n ${NAMESPACE}` otherwise it may not cleanup the releases in the proper namespace.

### Cleanup HTTPRoute

Follow provider specific instructions for deleting HTTPRoute.

#### Cleanup for "kgateway" or "istio"

```bash
kubectl delete -f httproute.yaml
```

#### Cleanup for "gke"

```bash
kubectl delete -f httproute.gke.yaml
```

## Customization

For information on customizing an installation of a quickstart path and tips to build your own, see [our docs](../../docs/customizing-a-quickstart-inference-stack.md)
