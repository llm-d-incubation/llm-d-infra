# Well-lit Path: Wide Expert Parallelism (EP/DP) with LeaderWorkerSet

## Overview

- This example demonstrates how to deploy DeepSeek-R1-0528 using vLLM's P/D disaggregation support with NIXL in a wide expert parallel pattern with LeaderWorkerSets
- This "path" has been validated on a Cluster with 16xH200 GPUs split across two nodes with InfiniBand networking

> WARNING: We are still investigating and optimizing performance for other hardware and networking configurations

In this example, we will demonstrate a deployment of `DeepSeek-R1-0528` with:

- 1 DP=8 Prefill Workers
- 2 DP=4 Decode Workers

## Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. If you do not have these, see [install-deps.sh](../../dependencies/install-deps.sh).

- Additionally, it is assumed you have configured and deployed your Gateway Control Plane, and their pre-requisite CRDs. For information on this see the [gateway-control-plane-providers](../../gateway-control-plane-providers/) directory.

- You must have the `llm-d-hf-token` secret in the namespace you want to deploy to with key `HF_TOKEN`. You can create one like so:

```bash
export NAMESPACE=llm-d-wide-ep # Or any namespace your heart desires
export HF_TOKEN=$(HFTOKEN)
kubectl create secret generic llm-d-hf-token \
    --from-literal="HF_TOKEN=${HF_TOKEN}" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
```

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-wide-ep` in this example.

```bash
export NAMESPACE=llm-d-wide-ep # Or any namespace your heart desires
cd quickstart/examples/wide-ep-lws
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

## Verifying the installation

1. First you should be able to see that both of your release of infra and modelservice charts went smoothly:

```bash
helm list -n ${NAMESPACE}
NAME          NAMESPACE     REVISION  UPDATED                               STATUS    CHART                     APP VERSION
infra-wide-ep llm-d-wide-ep 1         2025-08-21 12:50:44.051441 -0700 PDT  deployed  llm-d-infra-v1.2.4        v0.2.0
ms-wide-ep    llm-d-wide-ep 1         2025-08-21 12:50:48.398507 -0700 PDT  deployed  llm-d-modelservice-v0.2.7 v0.2.0
```

1. You should all the pods you expect to (2 decodes, 1 prefill, 1 gateway pod, 1 EPP pod):

```bash
kubectl get pods -n ${NAMESPACE}
NAME                                                     READY   STATUS    RESTARTS   AGE
infra-wide-ep-inference-gateway-istio-7f469d88b6-kbsn4   1/1     Running   0          6m17s
ms-wide-ep-llm-d-modelservice-decode-0                   2/2     Running   0          6m10s
ms-wide-ep-llm-d-modelservice-decode-0-1                 2/2     Running   0          6m10s
ms-wide-ep-llm-d-modelservice-epp-84588669cd-s4z7c       1/1     Running   0          6m11s
ms-wide-ep-llm-d-modelservice-prefill-0                  1/1     Running   0          6m10s
```

1. You should be able to do inferencing requests. The first thing we need to check is that all our vLLM servers have started which can take some time. We recommend using `stern` to grep the decode logs together and wait for the messaging saying that the vLLM API server is spun up:

```bash
DECODE_PODS=$(kubectl get pods -n ${NAMESPACE} -l "llm-d.ai/role=decode" --no-headers | awk '{print $1}' | tail -n 2)
stern "$(echo "$DECODE_PODS" | paste -sd'|' -)" -c vllm | grep -v "Avg prompt throughput"
```

Eventually you should see log lines indicating vLLM is ready to start accepting requests:

```log
ms-pd-llm-d-modelservice-decode-9666b4775-z8k46 vllm INFO 07-25 13:57:57 [api_server.py:1818] Starting vLLM API server 0 on http://0.0.0.0:8200
ms-pd-llm-d-modelservice-decode-9666b4775-z8k46 vllm INFO 07-25 13:57:57 [launcher.py:29] Available routes are:
ms-pd-llm-d-modelservice-decode-9666b4775-z8k46 vllm INFO 07-25 13:57:57 [launcher.py:37] Route: /openapi.json, Methods: GET, HEAD
ms-pd-llm-d-modelservice-decode-9666b4775-z8k46 vllm INFO 07-25 13:57:57 [launcher.py:37] Route: /docs, Methods: GET, HEAD
...
ms-pd-llm-d-modelservice-decode-9666b4775-z8k46 vllm INFO:     Started server process [1]
ms-pd-llm-d-modelservice-decode-9666b4775-z8k46 vllm INFO:     Waiting for application startup.
ms-pd-llm-d-modelservice-decode-9666b4775-z8k46 vllm INFO:     Application startup complete.
```

We also should make sure that prefill has come up:

```bash
PREFILL_POD=$(kubectl get pods -n ${NAMESPACE} -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=prefill" | tail -n 1 | awk '{print}')
kubectl logs pod/${PREFILL_POD} | grep -v "Avg prompt throughput"
```

Again look for the same server startup message, but instead of 2 aggregated into a single log stream with decode, you should only see 1 set of startup logs for prefill (hence the lack of `stern` here):

```log
INFO 07-25 18:46:12 [api_server.py:1818] Starting vLLM API server 0 on http://0.0.0.0:8000
INFO 07-25 18:46:12 [launcher.py:29] Available routes are:
INFO 07-25 18:46:12 [launcher.py:37] Route: /openapi.json, Methods: GET, HEAD
INFO 07-25 18:46:12 [launcher.py:37] Route: /docs, Methods: GET, HEAD
...
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

After this, we can port-forward your gateway service in one terminal:

```bash
kubectl port-forward -n ${NAMESPACE} service/infra-wide-ep-inference-gateway-istio 8000:80
```

And then you should be able to curl your gateway service:

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1753469354,
      "id": "deepseek-ai/DeepSeek-R1-0528",
      "max_model_len": 163840,
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
          "created": 1753469354,
          "group": null,
          "id": "modelperm-7e5c28aac82549b09291f748cf209bf4",
          "is_blocking": false,
          "object": "model_permission",
          "organization": "*"
        }
      ],
      "root": "deepseek-ai/DeepSeek-R1-0528"
    }
  ],
  "object": "list"
}
```

Finally, we should be able to perform inference with curl:

```bash
curl -s http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-ai/DeepSeek-R1-0528",
    "prompt": "I will start this from the first set of prompts and see where this gets routed. Were going to start by significantly jacking up the tokens so that we can ensure that this request gets routed properly with regard to PD. I also verified that all the gateway assets seem to be properly configured and as far as I can tell, there are no mismatches between assets. Everything seems set, lets hope that this works right now!",
    "max_tokens": 100,
    "ignore_eos": "true",
    "seed": "'$(date +%M%H%M%S)'"
  }' | jq
{
  "choices": [
    {
      "finish_reason": "length",
      "index": 0,
      "logprobs": null,
      "prompt_logprobs": null,
      "stop_reason": null,
      "text": " I'm going to use the following tokens to ensure that we get a proper response: \n\nToken: 250\nTemperature: 0.7\nMax Length: 500\nTop P: 1.0\nFrequency Penalty: 0.0\nPresence Penalty: 0.0\nStop Sequence: None\n\nNow, we are going to use the following prompt:\n\n\"Write a comprehensive and detailed tutorial on how to write a prompt that would be used with an AI like"
    }
  ],
  "created": 1753469430,
  "id": "cmpl-882f51e0-c2df-4284-a9a4-557b44ed00b9",
  "kv_transfer_params": null,
  "model": "deepseek-ai/DeepSeek-R1-0528",
  "object": "text_completion",
  "service_tier": null,
  "system_fingerprint": null,
  "usage": {
    "completion_tokens": 100,
    "prompt_tokens": 86,
    "prompt_tokens_details": null,
    "total_tokens": 186
  }
}
```

## Cleanup

To remove the deployment:

```bash
# Remove the model services
# From examples/wide-ep-lws
helmfile destroy

# Or uninstall them manually
helm uninstall ms-wide-ep -n ${NAMESPACE}
helm uninstall infra-wide-ep -n ${NAMESPACE}
```

## Customization

- **Change model**: Edit `ms-wide-ep/values.yaml` and update the `modelArtifacts.uri`, `modelArtifacts.name` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
