# Well-lit Path: Wide Expert Parallelism (EP/DP) with LeaderWorkerSet

## Overview

- This example demonstrates how to deploy DeepSeek-R1-0528 using vLLM's P/D disaggregation support with NIXL in a wide expert parallel pattern with LeaderWorkerSets
- This "path" has been validated on a Cluster with 16xH200 GPUs split across two nodes with InfiniBand networking

> WARNING: We are still investigating and optimizing performance for other hardware and networking configurations

In this example, we will demonstrate a deployment of `DeepSeek-R1-0528` with:

- 1 DP=8 Prefill Workers
- 2 DP=4 Decode Workers

## Installation

1. Install your local dependencies (from `/llm-d-infra/quickstart`)

   ```bash
   ./install-deps.sh
   ```

1. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart (from `/llm-d-infra/quickstart`). This example only works out of the box with `Istio` as a provider, but with changes its possible to run this with `kgateway`.

   ```bash
   export HF_TOKEN=${HFTOKEN}
   ./llmd-infra-installer.sh --namespace llm-d-wide-ep -r infra-wide-ep -f examples/wide-ep-lws/infra-wide-ep/values.yaml --disable-metrics-collection
   ```

   **_NOTE:_** The release name `infra-wide-ep` is important here, because it matches up with pre-built values files used in this example.

1. Use the helmfile to apply the modelservice chart on top of it

   ```bash
   cd examples/wide-ep-lws
   helmfile --selector managedBy=helmfile apply -f helmfile.yaml --skip-diff-on-install
   ```

## Verifying the installation

1. First you should be able to see that both of your release of infra and modelservice charts went smoothly:

```bash
$ helm list -n llm-d-wide-ep
NAME             NAMESPACE        REVISION    UPDATED                                 STATUS      CHART                        APP VERSION
infra-wide-ep    llm-d-wide-ep    1           2025-07-25 05:43:35.263697 -0700 PDT   deployed    llm-d-infra-v1.1.1           v0.2.0
ms-wide-ep       llm-d-wide-ep    1           2025-07-25 06:16:29.31419 -0700 PDT    deployed    llm-d-modelservice-v0.2.0    v0.2.0
```

1. You should all the pods you expect to (2 decodes, 1 prefill, 1 gateway pod, 1 EPP pod):

```bash
$ kubectl get pods -n llm-d-wide-ep
NAME                                                   READY   STATUS    RESTARTS   AGE
infra-wide-ep-inference-gateway-istio-7f4cf9f5-hpqg4   1/1     Running   0          55m
ms-wide-ep-llm-d-modelservice-decode-0                 2/2     Running   0          22m
ms-wide-ep-llm-d-modelservice-decode-0-1               2/2     Running   0          22m
ms-wide-ep-llm-d-modelservice-epp-749696866d-n24tx     1/1     Running   0          22m
ms-wide-ep-llm-d-modelservice-prefill-0                1/1     Running   0          22m
```

1. You should be able to do inferencing requests. The first thing we need to check is that all our vLLM servers have started which can take some time. We recommend using `stern` to grep the decode logs together and wait for the messaging saying that the vLLM API server is spun up:

```bash
DECODE_PODS=$(kubectl get pods -n llm-d-wide-ep -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=decode" --no-headers | awk '{print}' | tail -n 2)
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
PREFILL_POD=$(kubectl get pods -n llm-d-wide-ep -l "llm-d.ai/inferenceServing=true,llm-d.ai/role=prefill" | tail -n 1 | awk '{print}')
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
kubectl port-forward -n llm-d-wide-ep service/infra-wide-ep-inference-gateway-istio 8000:80
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
helmfile --selector managedBy=helmfile destroy -f helmfile.yaml

# Remove the infrastructure
helm uninstall infra-wide-ep -n llm-d-wide-ep
```

## Customization

- **Change model**: Edit `ms-wide-ep/values.yaml` and update the `modelArtifacts.uri` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
