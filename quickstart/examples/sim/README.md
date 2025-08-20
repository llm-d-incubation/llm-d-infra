# Feature: llm-d Simulation

## Overview

This is a simulation example that demonstrates how to deploy using the llm-d-infra system with the `ghcr.io/llm-d/llm-d-inference-sim` image. This example simulates inference responses and can run on minimal resources without requiring actual GPU hardware.

### Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. If you do not have these, see [install-deps.sh](../../install-deps.sh).

- Additionally, it is assumed you have configured and deployed your Gateway Control Plane, and their pre-requisite CRDs. For information on this see the [gateway-control-plane-providers](../../gateway-control-plane-providers/) directory.

**_NOTE:_** Unlike other examples which require models, the simulator stubs the vLLM server and so no `llm-d-hf-token` is needed.

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-sim` in this example.

```bash
export NAMESPACE=llm-d-sim # Or any namespace your heart desires
cd quickstart/examples/sim
helmfile apply
```

**_NOTE:_** This uses Istio as the default provider, see [Gateway Options](./README.md#gateway-options) for installing with a specific provider.

### Gateway options

Currently we support 3 gateway providers as `environments` in helmfile, those are `istio`, `kgateway` and `gke`. To install for that provider, simply pass the `-e <environment_name>` flag to your install as so:

```bash
# for kgateway:
helmfile apply -e kgateway
# for GKE:
helmfile apply -e gke
```

## Verify the Installation

- Firstly, you should be able to list all helm releases to view the 3 charts got installed into your chosen namespace:

```bash
helm list -n ${NAMESPACE}
NAME      NAMESPACE REVISION  UPDATED                               STATUS    CHART                     APP VERSION
gaie-sim  llm-d-sim 1         2025-08-20 07:45:52.387286 -0700 PDT  deployed  inferencepool-v0.5.1      v0.5.1
infra-sim llm-d-sim 1         2025-08-20 07:45:49.269596 -0700 PDT  deployed  llm-d-infra-v1.2.4        v0.2.0
ms-sim    llm-d-sim 1         2025-08-20 07:45:56.698955 -0700 PDT  deployed  llm-d-modelservice-v0.2.7 v0.2.0
```

### Finding your Endpoint

- Find the gateway service:

```bash
kubectl get services -n ${NAMESPACE}
NAME                                TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)                        AGE
gaie-sim-epp                        ClusterIP      172.30.135.207   <none>                                                                   9002/TCP,9090/TCP              10m
gaie-sim-ip-207d1d4c                ClusterIP      None             <none>                                                                   54321/TCP                      10m
infra-sim-inference-gateway-istio   LoadBalancer   172.30.182.184   a14d7f1f16a55447e8aae9e7ab268958-112801509.us-east-1.elb.amazonaws.com   15021:30887/TCP,80:31002/TCP   10m
```

**_NOTE:_** As mentioned above, this example uses Istio, your services will be named differently if you are using another provider.

If you are using the GKE gateway or have are using the default service type of `LoadBalancer` for you gateway and you are on a cloud platform with loadbalancing, you can use the `External IP` of your gateway service (you should see the same thing under your gateway with `kubectl get gateway`.)

```bash
export ENDPOINT=$(kubectl get gateway -n ${NAMESPACE} | \
  grep "infra-sim" | \
  awk '{print $3}')
```

**_NOTE:_** Here we are `grep`ing by the name `infra-sim` because that is the release name specified in the [helmfile](./helmfile.yaml.gotmpl#L28), if you change the release name, you will need to insure you have grabbed the `ENDPOINT` for your correct gateway.

If you are not on GKE and or selected the gateway service type of `NodePort`, you will have to port-forward the service and curl `localhost`

```bash
SERVICE_NAME=$(kubectl get services -n ${NAMESPACE} | grep "infra-sim" | awk '{print $1}' )
kubectl port-forward -n ${NAMESPACE} service/${SERVICE_NAME} 8000:80
```

In this example since we are port-forwarding, we know that our endpoint will be localhost:

```bash
export ENDPOINT="http://localhost:8000"
```

1. Try curling the `/v1/models` endpoint:

```bash
curl -s ${ENDPOINT}/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1752727169,
      "id": "random",
      "object": "model",
      "owned_by": "vllm",
      "parent": null,
      "root": "random"
    },
    {
      "created": 1752727169,
      "id": "",
      "object": "model",
      "owned_by": "vllm",
      "parent": "random",
      "root": ""
    }
  ],
  "object": "list"
}
```

1. Try curling the `v1/completions` endpoint:

```bash
curl -X POST ${ENDPOINT}/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{
        "model": "random",
        "prompt": "How are you today?"
      }' | jq
{
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "Today is a nice sunny day.",
        "role": "assistant"
      }
    }
  ],
  "created": 1752727735,
  "id": "chatcmpl-af42e9e3-dab0-420f-872b-d23353d982da",
  "model": "random"
}
```

## Cleanup

To remove the deployment:

```bash
# Remove the model services
# From examples/sim
helmfile --selector managedBy=helmfile destroy -f helmfile.yaml

# Remove the infrastructure
helm uninstall infra-sim -n llm-d-sim
```

## Customization

- **Change simulation behavior**: Edit `ms-sim/values.yaml` and update the simulation parameters
- **Adjust resources**: Modify the CPU/memory requests in the container specifications (no GPU required for simulation)
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
- **Different model simulation**: Update `routing.modelName` to simulate different model names
