
# Inference Scheduling on GKE

## Installation

1. Install the dependencies; see [install-deps.sh](../../install-deps.sh)
1. Use the quickstart to deploy Gateway CRDs + Gateway provider + Infra chart.

```bash
# Set common environment variables
export NAMESPACE=llm-d-inference-scheduling
export GATEWAY=gke-l7-regional-external-managed
```

```bash
# From the repo root
cd quickstart
export HF_TOKEN=$(YOUR_TOKEN)
./llmd-infra-installer.sh --namespace ${NAMESPACE} -r infra-inference-scheduling --gateway ${GATEWAY} --disable-metrics-collection
```

**_NOTE:_** It should be noted release name `infra-inference-scheduling` is important here, because it matches up with pre-built values files used in this example.

1. Use the helmfile to apply the modelservice and GIE charts on top of it.

```bash
cd examples/inference-scheduling
helmfile apply \
  --namespace ${NAMESPACE} \
  --selector managedBy=helmfile \
  apply -f gke.helmfile.yaml --skip-diff-on-install
```

## Verify the Installation

1. Firstly, you should be able to list all helm releases to view the 3 charts got installed into the `${NAMESPACE}` namespace:

```bash
$ helm list -n ${NAMESPACE}
NAME                       NAMESPACE                  REVISION UPDATED                              STATUS   CHART                     APP VERSION
gaie-inference-scheduling  llm-d-inference-scheduling 1        2025-07-24 10:44:30.543527 -0700 PDT deployed inferencepool-v0.5.1      v0.5.1
infra-inference-scheduling llm-d-inference-scheduling 1        2025-07-24 10:41:49.452841 -0700 PDT deployed llm-d-infra-v1.1.0         v0.2.0
ms-inference-scheduling    llm-d-inference-scheduling 1        2025-07-24 10:44:35.91079 -0700 PDT  deployed llm-d-modelservice-v0.2.0 v0.2.0
```

1. Get the gateway endpoint:

```bash
GATEWAY_NAME=infra-inference-scheduling-inference-gateway
IP=$(kubectl get gateway/${GATEWAY_NAME} -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')
PORT=80
```

1. Try curling the `/v1/models` endpoint:

```bash
curl http://${IP}:${PORT}/v1/models \
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

1. Try curling the `v1/completions` endpoint:

```bash
curl http://${IP}:${PORT}/v1/completions \
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
helmfile --selector managedBy=helmfile destroy --namespace ${NAMESPACE}

# Remove the infrastructure
helm uninstall infra-inference-scheduling --namespace ${NAMESPACE}
```
