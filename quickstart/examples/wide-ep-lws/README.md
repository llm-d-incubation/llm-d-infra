# Well-lit Path: Wide Expert Parallelism (EP/DP) with LeaderWorkerSet

## Overview

- This example demonstrates how to deploy DeepSeek-R1-0528 using vLLM's P/D disaggregation support with NIXL in a wide expert parallel pattern with LeaderWorkerSets
- This "path" has been validated on a Cluster with 16xH200 GPUs split across two nodes with InfiniBand networking

> WARNING: We are still investigating and optimizing performance for other hardware and networking configurations

In this example, we will demonstrate a deployment of `DeepSeek-R1-0528` with:

- 1 DP=8 Prefill Workers
- 2 DP=4 Decode Workers

## Hardware Requirements

This example out of the box requires 16 Nvidia H200 GPUs, and Inifiniband RDMA. It requires 1024 Gi of memory across and 128 Gi of ephemeral storage all 3 pods (512 Gi memory and 64 Gi storage for both Decode pods together and 512 Gi memory and 64 Gi storage for the prefill pod).

## Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. To see what those tools are and minimum versions, check [our docs](../../dependencies/README.md#required-tools), and to install them, see our [install-deps.sh](../../dependencies/install-deps.sh) script.

- You must have the secret containing a HuggingFace Token in the namespace you want to deploy to with key `HF_TOKEN` (see [instructions](../../dependencies/README.md#huggingface-token)).

- Additionally, it is assumed you have configured and deployed your Gateway Control Plane, and their pre-requisite CRDs. For information on this see the [gateway-control-plane-providers](../../gateway-control-plane-providers/) directory.

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-wide-ep` in this example.

```bash
export NAMESPACE=llm-d-wide-ep # or any other namespace
cd quickstart/examples/wide-ep-lws
helmfile apply -n ${NAMESPACE}
```

**_NOTE:_** You can set the `$RELEASE_NAME_POSTFIX` env variable to change the release names. This is how we support concurrent installs. Ex: `RELEASE_NAME_POSTFIX=wide-ep-2 helmfile apply -n ${NAMESPACE}`

**_NOTE:_** This uses Istio as the default provider, see [Gateway Options](./README.md#gateway-options) for installing with a specific provider.

### Gateway options

To see specify your gateway choice you can use the `-e <gateway option>` flag, ex:

```bash
helmfile apply -e kgateway -n ${NAMESPACe}
```

To see what gateway options are supported refer to our [gateway control plane docs](../../gateway-control-plane-providers/README.md#supported-providers). Gateway configurations per provider are tracked in the [gateway-configurations directory](../common/gateway-configurations/).

You can also customize your gateway, for more information on how to do that see our [gateway customization docs](../../docs/customizing-your-gateway.md).

## Verifying the installation

- Firstly, you should be able to list all helm releases to view both of the 2 charts got installed into your chosen namespace:

```bash
helm list -n ${NAMESPACE}
NAME            NAMESPACE       REVISION    UPDATED                                 STATUS      CHART                       APP VERSION
infra-wide-ep   llm-d-wide-ep   1           2025-08-24 13:14:53.355639 -0700 PDT    deployed    llm-d-infra-v1.3.0          v0.3.0
ms-wide-ep      llm-d-wide-ep   1           2025-08-24 13:14:57.614439 -0700 PDT    deployed    llm-d-modelservice-v0.2.7   v0.2.0
```

- Out of the box with this example you should have the following resources:

```bash
kubectl get all -n ${NAMESPACE}
NAME                                                         READY   STATUS    RESTARTS   AGE
pod/infra-wide-ep-inference-gateway-istio-74d5c66c86-h5mfn   1/1     Running   0          2m22s
pod/ms-wide-ep-llm-d-modelservice-decode-0                   2/2     Running   0          2m13s
pod/ms-wide-ep-llm-d-modelservice-decode-0-1                 2/2     Running   0          2m13s
pod/ms-wide-ep-llm-d-modelservice-epp-55bb9857cf-4pj6r       1/1     Running   0          2m14s
pod/ms-wide-ep-llm-d-modelservice-prefill-0                  1/1     Running   0          2m13s

NAME                                            TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                        AGE
service/infra-wide-ep-inference-gateway-istio   LoadBalancer   10.16.1.34    10.16.4.2     15021:30312/TCP,80:33662/TCP   2m22s
service/ms-wide-ep-ip-1e480070                  ClusterIP      None          <none>        54321/TCP                      2d4h
service/ms-wide-ep-llm-d-modelservice-decode    ClusterIP      None          <none>        <none>                         2m13s
service/ms-wide-ep-llm-d-modelservice-epp       ClusterIP      10.16.1.137   <none>        9002/TCP                       2d4h
service/ms-wide-ep-llm-d-modelservice-prefill   ClusterIP      None          <none>        <none>                         2m13s

NAME                                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/infra-wide-ep-inference-gateway-istio   1/1     1            1           2m22s
deployment.apps/ms-wide-ep-llm-d-modelservice-epp       1/1     1            1           2m14s

NAME                                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/infra-wide-ep-inference-gateway-istio-74d5c66c86   1         1         1       2m22s
replicaset.apps/ms-wide-ep-llm-d-modelservice-epp-55bb9857cf       1         1         1       2m14s

NAME                                                      READY   AGE
statefulset.apps/ms-wide-ep-llm-d-modelservice-decode     1/1     2m13s
statefulset.apps/ms-wide-ep-llm-d-modelservice-decode-0   1/1     2m13s
statefulset.apps/ms-wide-ep-llm-d-modelservice-prefill    1/1     2m13s
```

**_NOTE:_** This assumes no other quickstart deployments in your given `${NAMESPACE}` and you have not changed the default release names via the `${RELEASE_NAME}` environment variable.

## Using the stack

For instructions on getting started making inference requests see [our docs](../../docs/getting-started-inferencing.md)

**_NOTE:_** This example particularly benefits from utilizing stern as described in the [getting-started-inferencing docs](../../docs/getting-started-inferencing.md#following-logs-for-requests), because while we only have 3 inferencing pods, it has 16 vllm servers or ranks.

**_NOTE:_** Compared to the other examples, this one takes anywhere between 7-10 minutes for the vllm API servers to startup so this might take longer before you can interact with this example.

## Cleanup

To remove the deployment:

```bash
# From examples/wide-ep-lws
helmfile destroy -n ${NAMESPACE}

# Or uninstall them manually
helm uninstall ms-wide-ep -n ${NAMESPACE}
helm uninstall infra-wide-ep -n ${NAMESPACE}
```

**_NOTE:_** If you set the `$RELEASE_NAME_POSTFIX` environment variable, your release names will be different from the command above: `infra-$RELEASE_NAME_POSTFIX`, `gaie-$RELEASE_NAME_POSTFIX` and `ms-$RELEASE_NAME_POSTFIX`.

**_NOTE:_** You do not need to specify your `environment` with the `-e <environment>` flag to `helmfile` for removing a installation of the quickstart, even if you use a non-default option.

## Customization

For information on customizing an installation of a quickstart path and tips to build your own, see [our docs](../../docs/customizing-a-quickstart-inference-stack.md)
