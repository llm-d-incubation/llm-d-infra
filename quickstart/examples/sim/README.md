# Feature: llm-d Simulation

## Overview

This is a simulation example that demonstrates how to deploy using the llm-d-infra system with the `ghcr.io/llm-d/llm-d-inference-sim` image. This example simulates inference responses and can run on minimal resources without requiring actual GPU hardware.

## Apple Silicon Local Deployment

If you want to deploy this stack locally on an Apple Silicon machine, please refer to the [local-apple-silicon README](./local-apple-silicon/README.md) for specific instructions and configuration overrides.

## Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. To see what those tools are and minimum versions, check [our docs](../../dependencies/README.md#required-tools), and to install them, see our [install-deps.sh](../../dependencies/install-deps.sh) script.

- Additionally, it is assumed you have configured and deployed your Gateway Control Plane, and their pre-requisite CRDs. For information on this see the [gateway-control-plane-providers](../../gateway-control-plane-providers/) directory.

**_NOTE:_** Unlike other examples which require models, the simulator stubs the vLLM server and so no HuggingFace token is needed.

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-sim` in this example.

```bash
export NAMESPACE=llm-d-sim # Or any namespace your heart desires
cd quickstart/examples/sim
helmfile apply -n ${NAMESPACE}
```

**_NOTE:_** You can set the `$RELEASE_NAME_POSTFIX` env variable to change the release names. This is how we support concurrent installs. ex: `RELEASE_NAME_POSTFIX=sim-2 helmfile apply -n ${NAMESPACE}`

**_NOTE:_** This uses Istio as the default provider, see [Gateway Options](./README.md#gateway-options) for installing with a specific provider.

### Gateway options

To see specify your gateway choice you can use the `-e <gateway option>` flag, ex:

```bash
helmfile apply -e kgateway -n ${NAMESPACE}
```

To see what gateway options are supported refer to our [gateway control plane docs](../../gateway-control-plane-providers/README.md#supported-providers). Gateway configurations per provider are tracked in the [gateway-configurations directory](../common/gateway-configurations/).

You can also customize your gateway, for more information on how to do that see our [gateway customization docs](../../docs/customizing-your-gateway.md).

## Verify the Installation

- Firstly, you should be able to list all helm releases to view the 3 charts got installed into your chosen namespace:

```bash
helm list -n ${NAMESPACE}
NAME        NAMESPACE   REVISION   UPDATED                               STATUS     CHART                       APP VERSION
gaie-sim    llm-d-sim   1          2025-08-24 11:44:26.88254 -0700 PDT   deployed   inferencepool-v0.5.1        v0.5.1
infra-sim   llm-d-sim   1          2025-08-24 11:44:23.11688 -0700 PDT   deployed   llm-d-infra-v1.3.0          v0.3.0
ms-sim      llm-d-sim   1          2025-08-24 11:44:32.17112 -0700 PDT   deployed   llm-d-modelservice-v0.2.9   v0.2.0
```

- Out of the box with this example you should have the following resources:

```bash
kubectl get all -n ${NAMESPACE}
NAME                                                     READY   STATUS    RESTARTS   AGE
pod/gaie-sim-epp-694bdbd44c-4sh92                        1/1     Running   0          7m14s
pod/infra-sim-inference-gateway-istio-68d59c4778-n6n5l   1/1     Running   0          7m19s
pod/ms-sim-llm-d-modelservice-decode-674774f45d-hhlxl    2/2     Running   0          7m10s
pod/ms-sim-llm-d-modelservice-decode-674774f45d-p5lsx    2/2     Running   0          7m10s
pod/ms-sim-llm-d-modelservice-decode-674774f45d-zpp84    2/2     Running   0          7m10s
pod/ms-sim-llm-d-modelservice-prefill-76c86dd9f8-pvbzm   1/1     Running   0          7m10s

NAME                                        TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                        AGE
service/gaie-sim-epp                        ClusterIP      10.16.0.143   <none>        9002/TCP,9090/TCP              7m14s
service/gaie-sim-ip-207d1d4c                ClusterIP      None          <none>        54321/TCP                      7m14s
service/infra-sim-inference-gateway-istio   LoadBalancer   10.16.1.112   10.16.4.2     15021:33302/TCP,80:31413/TCP   7m19s

NAME                                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/gaie-sim-epp                        1/1     1            1           7m14s
deployment.apps/infra-sim-inference-gateway-istio   1/1     1            1           7m19s
deployment.apps/ms-sim-llm-d-modelservice-decode    3/3     3            3           7m10s
deployment.apps/ms-sim-llm-d-modelservice-prefill   1/1     1            1           7m10s

NAME                                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/gaie-sim-epp-694bdbd44c                        1         1         1       7m15s
replicaset.apps/infra-sim-inference-gateway-istio-68d59c4778   1         1         1       7m20s
replicaset.apps/ms-sim-llm-d-modelservice-decode-674774f45d    3         3         3       7m11s
replicaset.apps/ms-sim-llm-d-modelservice-prefill-76c86dd9f8   1         1         1       7m11s
```

**_NOTE:_** This assumes no other quickstart deployments in your given `${NAMESPACE}`.

## Using the stack

For instructions on getting started making inference requests see [our docs](../../docs/getting-started-inferencing.md)

## Cleanup

To remove the deployment:

```bash
# From examples/sim
helmfile destroy -n ${NAMESPACE}

# Or uninstall manually
helm uninstall infra-sim -n ${NAMESPACE}
helm uninstall gaie-sim -n ${NAMESPACE}
helm uninstall ms-sim -n ${NAMESPACE}
```

**_NOTE:_** If you set the `$RELEASE_NAME_POSTFIX` environment variable, your release names will be different from the command above: `infra-$RELEASE_NAME_POSTFIX`, `gaie-$RELEASE_NAME_POSTFIX` and `ms-$RELEASE_NAME_POSTFIX`.

**_NOTE:_** You do not need to specify your `environment` with the `-e <environment>` flag to `helmfile` for removing a installation of the quickstart, even if you use a non-default option. You do, however, have to set the `-n ${NAMESPACE}` otherwise it may not cleanup the releases in the proper namespace.

## Customization

For information on customizing an installation of a quickstart path and tips to build your own, see [our docs](../../docs/customizing-a-quickstart-inference-stack.md)
