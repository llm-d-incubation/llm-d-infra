# Well-lit Path: Wide Expert Parallelism (EP/DP) with LeaderWorkerSet

## Warning ⚠️: Here there be Dragons

In an effort to demonstrate the potential of LLM-D we wanted to build this more advanced and performant example. However to do this, we had to opinionate this example more than the others to the specfics of our development environment. The most notorious of this is that the containers run privileged and as root - this is pretty much table stakes for running any performant infernecing workload at sclae but still it should be mentioned. "Here, there be dragons" - be warned.

## Overview

- This example demonstrates how to deploy DeepSeek-R1-0528 using vLLM's P/D disaggregation support with NIXL in a wide expert parallel pattern with LeaderWorkerSets
- This "path" has been validated on a Cluster with 16xH200 GPUs split across two nodes with infiniband networking

> WARNING: We are still investigating and optimizing performance for other hardware and networking configurations

In this example, we will demonstrate a deployment of `DeepSeek-R1-0528` with:
- 1 DP=8 Prefill Workers
- 2 DP=4 Decode Worker

## Installation

1. Install your local dependencies (from `/llm-d-infra/quickstart`)

```bash
./install-deps.sh
```

2. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart (from `/llm-d-infra/quickstart`). This example only works out of the box with `Istio` as a provider, but with changes its possible to run this with `kgateway`.
```bash
export HF_TOKEN=${HFTOKEN}
./llmd-infra-installer.sh --namespace llm-d-wide-ep -r infra-wide-ep -f examples/wide-ep-lws/infra-wide-ep/values.yaml --disable-metrics-collection
```

3. Use the helmfile to apply the modelservice chart on top of it
```bash
cd examples/wide-ep-lws
helmfile --selector managedBy=helmfile apply --skip-diff-on-install
```

This should spin everything up that you need.

## Verifying the installation

1. First you should be able to see that both of your release of infra and modelservice charts went smoothly:

```bash
helm list
NAME         	NAMESPACE    	REVISION	UPDATED                             	STATUS  	CHART                    	APP VERSION
infra-wide-ep	llm-d-wide-ep	1       	2025-07-25 05:43:35.263697 -0700 PDT	deployed	llm-d-infra-1.0.8        	0.1
ms-wide-ep   	llm-d-wide-ep	1       	2025-07-25 06:16:29.31419 -0700 PDT 	deployed	llm-d-modelservice-0.0.19	0.0.1
```

2. You should all the pods you expect to (2 decodes, 1 prefill, 1 gateway pod, 1 EPP pod):

```bash
$ kubectl get pods
NAME                                                   READY   STATUS    RESTARTS   AGE
infra-wide-ep-inference-gateway-istio-7f4cf9f5-hpqg4   1/1     Running   0          55m
ms-wide-ep-llm-d-modelservice-decode-0                 2/2     Running   0          22m
ms-wide-ep-llm-d-modelservice-decode-0-1               2/2     Running   0          22m
ms-wide-ep-llm-d-modelservice-epp-749696866d-n24tx     1/1     Running   0          22m
ms-wide-ep-llm-d-modelservice-prefill-0                1/1     Running   0          22m
```

3. You should be able to do inferencing requests. Start by port-forwarding your gateway service in one terminal:

```bash
$ kubectl port-forward service/infra-wide-ep-inference-gateway-istio 8000:80
```

And then you should be able to curl your gateway service:

```bash
$ curl http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   508    0   508    0     0   1626      0 --:--:-- --:--:-- --:--:--  1628
{
  "data": [
    {
      "created": 1753450815,
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
          "created": 1753450815,
          "group": null,
          "id": "modelperm-f687ed61ea0e4633bee2bc5adce14d70",
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

$ curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-ai/DeepSeek-R1-0528",
    "prompt": "I will start this from the first set of prompts and see where this gets routed. Were going to start by significantly jacking up the tokens so that we can ensure that this request gets routed properly with regard to PD. I also verified that all the gateway assets seem to be properly configured and as far as I can tell, there are no mismatches between assets. Everything seems set, lets hope that this works right now!",
    "max_tokens": 100,
    "ignore_eos": "true",
    "seed": "'$(date +%M%H%M%S)'"
  }'

{"choices":[{"finish_reason":"length","index":0,"logprobs":null,"prompt_logprobs":null,"stop_reason":null,"text":" I will also make sure to specify the model appropriately.\r\n\r\n# Important Considerations\r\n1. **Token Management**: The tokens have been increased to 8192 to handle the entire context without truncation.\r\n2. **Model Specification**: Explicitly set the model to `gpt-4-1106-preview` to match the intended use.\r\n3. **Document Structure**: The document is structured with clear headings and code blocks for readability.\r\n4."}],"created":1753450859,"id":"cmpl-2c50d70e-0445-4312-8c35-bfd361dd0c28","kv_transfer_params":null,"model":"deepseek-ai/DeepSeek-R1-0528","object":"text_completion","service_tier":null,"system_fingerprint":null,"usage":{"completion_tokens":100,"prompt_tokens":87,"prompt_tokens_details":null,"total_tokens":187}}
```
