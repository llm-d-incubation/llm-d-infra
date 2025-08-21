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

## Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. If you do not have these, see [install-deps.sh](../../install-deps.sh).

- Additionally, it is assumed you have configured and deployed your Gateway Control Plane, and their pre-requisite CRDs. For information on this see the [gateway-control-plane-providers](../../gateway-control-plane-providers/) directory.

- You must have the `llm-d-hf-token` secret in the namespace you want to deploy to with key `HF_TOKEN`. You can create one like so:

```bash
export NAMESPACE=llm-d-inference-scheduling # Or any namespace your heart desires
export HF_TOKEN=$(HFTOKEN)
kubectl create secret generic llm-d-hf-token \
    --from-literal="HF_TOKEN=${HF_TOKEN}" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
```

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-pd` in this example.

```bash
export NAMESPACE=llm-d-inference-scheduling # Or any namespace your heart desires
cd quickstart/examples/inference-scheduling
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
NAME      NAMESPACE     REVISION  UPDATED                               STATUS    CHART                     APP VERSION
gaie-pd   greg-test-pd  1         2025-08-21 11:11:31.432777 -0700 PDT  deployed  inferencepool-v0.5.1      v0.5.1
infra-pd  greg-test-pd  1         2025-08-21 11:11:27.472217 -0700 PDT  deployed  llm-d-infra-v1.2.4        v0.2.0
ms-pd     greg-test-pd  1         2025-08-21 11:24:13.722984 -0700 PDT  deployed  llm-d-modelservice-v0.2.7 v0.2.0
```

1. Next, let's check the pod health of our 4 prefill replicas and 1 decode replica:

```bash
kubectl get pods -n ${NAMESPACE}
NAME                                                READY   STATUS    RESTARTS   AGE
gaie-pd-epp-5668558c48-g52gm                        1/1     Running   0          57m
infra-pd-inference-gateway-istio-5b4c4d6c67-28lr4   1/1     Running   0          57m
ms-pd-llm-d-modelservice-decode-84bf6d5bdd-4cmhf    2/2     Running   0          45m
ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-g89j8   1/1     Running   0          45m
ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-gffmq   1/1     Running   0          45m
ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-ttxrl   1/1     Running   0          45m
ms-pd-llm-d-modelservice-prefill-86f6fb7cdc-whlx5   1/1     Running   0          45m
```

1. Find the gateway service:

```bash
kubectl get services -n ${NAMESPACE}
NAME                               TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                        AGE
gaie-pd-epp                        ClusterIP      10.16.3.24    <none>        9002/TCP,9090/TCP              58m
gaie-pd-ip-bb618139                ClusterIP      None          <none>        54321/TCP                      58m
infra-pd-inference-gateway-istio   LoadBalancer   10.16.0.137   10.16.4.2     15021:35235/TCP,80:35516/TCP   58m
```

In this case we have found that our gateway service is called `infra-pd-inference-gateway-istio`.

1. `port-forward` the service so we can curl it:

```bash
kubectl port-forward -n ${NAMESPACE} service/infra-pd-inference-gateway-istio 8000:80
```

1. Try curling the `/v1/models` endpoint:

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1755803409,
      "id": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic",
      "max_model_len": 32000,
      "object": "model",
      "owned_by": "vllm",
      "parent": null,
      "permission": [
        {
          "allow_create_engine": false,
          "allow_fine_tuning": false,
          "allow_logprobs": true,
          "allow_sampling": true,
          "allow_search_indices": false,
          "allow_view": true,
          "created": 1755803409,
          "group": null,
          "id": "modelperm-88297a39f4f8440ab458d10ac34a59ae",
          "is_blocking": false,
          "object": "model_permission",
          "organization": "*"
        }
      ],
      "root": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic"
    }
  ],
  "object": "list"
}
```

1. Try curling the `v1/completions` endpoint:

```bash
curl -s http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic",
    "prompt": "How are you today?",
    "max_tokens": 50
  }' | jq
{
  "choices": [
    {
      "finish_reason": "length",
      "index": 0,
      "logprobs": null,
      "prompt_logprobs": null,
      "stop_reason": null,
      "text": " I hope you're having a great day, despite the weather. I'm just dropping by to say hi and to share with you a few things that I've been loving lately. As you know, I'm a big fan of trying out new products"
    }
  ],
  "created": 1755803424,
  "id": "cmpl-64e41b3e-b2a4-46c3-a734-7c0fed6ee6ab",
  "kv_transfer_params": null,
  "model": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic",
  "object": "text_completion",
  "service_tier": null,
  "system_fingerprint": null,
  "usage": {
    "completion_tokens": 50,
    "prompt_tokens": 6,
    "prompt_tokens_details": null,
    "total_tokens": 56
  }
}
```

## Cleanup

To remove the deployment:

```bash
# Remove the model services
# From examples/inference-scheduling
helmfile destroy

# Remove the infrastructure
helm uninstall ms-pd -n ${NAMESPACE}
helm uninstall gaie-pd -n ${NAMESPACE}
helm uninstall infra-pd -n ${NAMESPACE}
```

## Customization

- **Change model**: Edit `ms-pd/values.yaml` and update the `modelArtifacts.uri`, `modelArtifacts.name` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
