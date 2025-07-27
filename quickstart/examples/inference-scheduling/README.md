# Well-lit Path: Intelligent Inference Scheduling

## Overview

This example deploys the recommended out of the box [scheduling configuration](https://github.com/llm-d/llm-d-inference-scheduler/blob/main/docs/architecture.md) for most vLLM deployments, reducing tail latency and increasing throughput through load-aware and prefix-cache aware balancing. This can be run on a single GPU that can load [Qwen/Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B).

This profile defaults to the approximate prefix cache aware scorer, which only observes request traffic to predict prefix cache locality. The [precise prefix cache aware routing feature](../precise-prefix-cache-aware) improves hit rate by introspecting the vLLM instances for cache entries and will become the default in a future release.

## Installation

> To adjust the model or any other modelservice values, simply change the values.yaml file in [ms-inference-scheduling/values.yaml](ms-inference-scheduling/values.yaml)

1. Install the dependencies; see [install-deps.sh](../../install-deps.sh)

2. Use the quickstart to deploy Gateway CRDs + Gateway provider + Infra chart. This example uses `kgateway` but should work with `istio` given some modifications as described below step 3. If you use GKE Gateway, please refer to [gke.md](./gke.md).

```bash
# From the repo root
cd quickstart
export HF_TOKEN=${HFTOKEN}
./llmd-infra-installer.sh --namespace llm-d-inference-scheduling -r infra-inference-scheduling --gateway kgateway --disable-metrics-collection
```

**_NOTE:_** The release name `infra-inference-scheduling` is important here, because it matches up with pre-built values files used in this example.

3. Use the helmfile to apply the modelservice and GIE charts on top of it.

```bash
cd examples/inference-scheduling
helmfile --selector managedBy=helmfile apply -f helmfile.yaml --skip-diff-on-install
```

**_NOTE:_** This examples was built with `kgateway` in mind. If you are deploying Istio as the gateway, e.g. `--gateway istio`, then you will need to apply a `DestinationRule` described in [Temporary Istio Workaround](../../istio-workaround.md).

## Verify the Installation

1. Firstly, you should be able to list all helm releases to view the 3 charts got installed into the `llm-d-inference-scheduling` namespace:

```bash
$ helm list -n llm-d-inference-scheduling
NAME                      	NAMESPACE                 	REVISION	UPDATED                             	STATUS  	CHART                    	APP VERSION
gaie-inference-scheduling 	llm-d-inference-scheduling	1       	2025-07-24 10:44:30.543527 -0700 PDT	deployed	inferencepool-v0.5.1     	v0.5.1
infra-inference-scheduling	llm-d-inference-scheduling	1       	2025-07-24 10:41:49.452841 -0700 PDT	deployed	llm-d-infra-v1.1.0        v0.2.0
ms-inference-scheduling   	llm-d-inference-scheduling	1       	2025-07-24 10:44:35.91079 -0700 PDT 	deployed	llm-d-modelservice-v0.2.0	v0.2.0
```

2. Find the gateway service:
```bash
$ kubectl get services -n llm-d-inference-scheduling
NAME                                           TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)             AGE
gaie-inference-scheduling-epp                  ClusterIP   10.16.0.249   <none>        9002/TCP,9090/TCP   96s
infra-inference-scheduling-inference-gateway   NodePort    10.16.3.58    <none>        80:33377/TCP        4m19s
```
In this case we have found that our gateway service is called `infra-inference-scheduling-inference-gateway`.

3. `port-forward` the service to we can curl it:

```bash
kubectl port-forward -n llm-d-inference-scheduling service/infra-inference-scheduling-inference-gateway 8000:80
```

4. Try curling the `/v1/models` endpoint:

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1752516744,
      "id": "Qwen/Qwen3-0.6B",
      "max_model_len": 2048,
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
          "created": 1752516744,
          "group": null,
          "id": "modelperm-d702cfd969b04aa8830ec448960d5e98",
          "is_blocking": false,
          "object": "model_permission",
          "organization": "*"
        }
      ],
      "root": "Qwen/Qwen3-0.6B"
    }
  ],
  "object": "list"
}
```

5. Try curling the `v1/completions` endpoint:
```bash
curl -s http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-0.6B",
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
      "text": "\nNot a bad day, thought I might cry in here if I stopped... Settled right in there with my stomach full of ache :(\nIt's normal to feel slightly better, just keep it up and you'll be fine :)\nthanks"
    }
  ],
  "created": 1752516865,
  "id": "cmpl-d960ff24-1a65-4614-a986-0ce87d1a83ea",
  "kv_transfer_params": null,
  "model": "Qwen/Qwen3-0.6B",
  "object": "text_completion",
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
helmfile --selector managedBy=helmfile destroy -f helmfile.yaml

# Remove the infrastructure
helm uninstall infra-inference-scheduling -n llm-d-inference-scheduling
```

## Customization

- **Change model**: Edit `ms-inference-scheduling/values.yaml` and update the `modelArtifacts.uri` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
