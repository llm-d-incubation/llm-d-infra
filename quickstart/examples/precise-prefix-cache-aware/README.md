# Feature: Precise Prefix Cache Aware Routing

## Overview

This is a simple quickstart demonstrating how to configure the inference scheduler to use the new precise prefix cache aware routing based on [vLLM KV-Events](https://github.com/vllm-project/vllm/issues/16669) data. Precise prefix cache aware routing pulls up-to-date prefix cache status from serving instances, eliminating the need for additional indexing services and increasing cache hit rate at high throughput.

### Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. If you do not have these, see [install-deps.sh](../../dependencies/install-deps.sh).

- Additionally, it is assumed you have configured and deployed your Gateway Control Plane, and their pre-requisite CRDs. For information on this see the [gateway-control-plane-providers](../../gateway-control-plane-providers/) directory.

- You must have the `llm-d-hf-token` secret in the namespace you want to deploy to with key `HF_TOKEN`. You can create one like so:

```bash
export NAMESPACE=llm-d-precise # Or any namespace your heart desires
export HF_TOKEN=$(HFTOKEN)
kubectl create secret generic llm-d-hf-token \
    --from-literal="HF_TOKEN=${HF_TOKEN}" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
```

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-precise` in this example.

```bash
export NAMESPACE=llm-d-precise # Or any namespace your heart desires
cd quickstart/examples/precise-prefix-cache-aware
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

1. Firstly, you should be able to list all helm releases in the `llm-d-precise` ns to view all 3 charts that should be installed:

```bash
helm list -n ${NAMESPACE}
NAME            NAMESPACE     REVISION  UPDATED                               STATUS    CHART                     APP VERSION
gaie-kv-events  llm-d-precise 2         2025-08-21 09:28:54.750853 -0700 PDT  deployed  inferencepool-v0.5.1      v0.5.1
infra-kv-events llm-d-precise 2         2025-08-21 09:31:42.076935 -0700 PDT  deployed  llm-d-infra-v1.2.4        v0.2.0
ms-kv-events    llm-d-precise 1         2025-08-21 09:24:05.957874 -0700 PDT  deployed  llm-d-modelservice-v0.2.7 v0.2.0
```

Note: if you chose to use `istio` as your Gateway provider you would see those (`istiod` and `istio-base` in the `istio-system` namespace) instead of the kgateway based ones.

- Find the gateway service:

```bash
kubectl get services -n ${NAMESPACE}
NAME                                      TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                        AGE
gaie-kv-events-epp                        ClusterIP      172.30.82.88     <none>                                                                    9002/TCP,9090/TCP,5557/TCP     9m54s
gaie-kv-events-ip-805c964d                ClusterIP      None             <none>                                                                    54321/TCP                      9m49s
infra-kv-events-inference-gateway-istio   LoadBalancer   172.30.168.117   aea17eb0f86a54359809595228bbfd69-1351462786.us-east-1.elb.amazonaws.com   15021:30834/TCP,80:30770/TCP   9m58s
```

In this case we have found that our gateway service is called `infra-inference-scheduling-inference-gateway-istio`.

1. `port-forward` the service so we can curl it:

```bash
kubectl -n llm-d-precise port-forward service/infra-kv-events-inference-gateway-istio 8000:80
```

1. Try curling the `/v1/models` endpoint:

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1755794609,
      "id": "Qwen/Qwen3-0.6B",
      "max_model_len": 40960,
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
          "created": 1755794609,
          "group": null,
          "id": "modelperm-d60a62ec11034c1e8d88580f6656d686",
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

1. Curl the `v1/completions` endpoint once:

```bash
export LONG_TEXT_200_WORDS="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." && \
curl -s http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-0.6B",
    "prompt": "'"$LONG_TEXT_200_WORDS"'",
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
      "text": " Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor"
    }
  ],
  "created": 1755794629,
  "id": "cmpl-ba363b6b-3462-444b-afb3-2e5935b278f8",
  "kv_transfer_params": null,
  "model": "Qwen/Qwen3-0.6B",
  "object": "text_completion",
  "service_tier": null,
  "system_fingerprint": null,
  "usage": {
    "completion_tokens": 50,
    "prompt_tokens": 192,
    "prompt_tokens_details": null,
    "total_tokens": 242
  }
}
```

1. Check the inference-scheduler's prefix-cache-scorer's scores with the following command:

```bash
kubectl logs -l inferencepool=gaie-kv-events-epp -n ${NAMESPACE} --tail 100 | grep "Got pod scores"
```

You should see output similar to:

```bash
2025-08-21T16:43:49Z  LEVEL(-4) prefix-cache-scorer/prefix-cache-scorer scorer/prefix_cache_tracking.go:125 Got pod scores  {"x-request-id": "ba363b6b-3462-444b-afb3-2e5935b278f8", "model": "Qwen/Qwen3-0.6B", "resolvedTargetModel": "Qwen/Qwen3-0.6B", "criticality": "Sheddable", "scores": null}
```

1. Repeat steps 5 and 6 to see the prefix-cache-scorer in action

You should see output similar to:

```log
2025-07-18T22:00:24Z    LEVEL(-4)       prefix-cache-scorer/prefix-cache-scorer scorer/prefix_cache_tracking.go:133     Got pod scores  {"x-request-id": "0e08703d-30c0-4624-a7b3-31e94dc99bc8", "model": "Qwen/Qwen3-0.6B", "resolvedTargetModel": "Qwen/Qwen3-0.6B", "criticality": "Sheddable", "scores": null}
2025-07-18T22:00:46Z    LEVEL(-4)       prefix-cache-scorer/prefix-cache-scorer scorer/prefix_cache_tracking.go:133     Got pod scores  {"x-request-id": "8d0b587d-058f-4d2e-a062-a859a565d37a", "model": "Qwen/Qwen3-0.6B", "resolvedTargetModel": "Qwen/Qwen3-0.6B", "criticality": "Sheddable", "scores": {"${POD_IP}":2}}
```

Notice that the second time we called the `/v1/completions` endpoint, the prefix-cache-scorer was able to return a score for the pod,
indicating that it had cached the KV-blocks from the first call.

1. See the `kvblock.Index` metrics in the `gaie-kv-events-epp` pod:

```bash
kubectl logs -l inferencepool=gaie-kv-events-epp -n llm-d-precise --tail 100 | grep "metrics beat"
```

You should see output similar to:

```log
I0718 23:57:10.781371       1 collector.go:107] "metrics beat" logger="metrics" admissions=3 evictions=0 lookups=1 hits=2 latency_count=1 latency_sum=0.000006859 latency_avg=0.0000022863333333333334
```

The `admissions` count indicates how many KV-blocks were added to the index through vLLM's KV-Events,
while the `hits` count indicates how many times the index was able to find a KV-block for a pod.

If the beat is missing lookups, wait for the next one (1 minute beats).

## Cleanup

To remove the deployment:

```bash
# Remove the model services
# From examples/precise-prefix-cache-aware
helmfile destroy

# Or uninstall manually
helm uninstall infra-kv-events -n ${NAMESPACE}
helm uninstall gaie-kv-events -n ${NAMESPACE}
helm uninstall ms-kv-events -n ${NAMESPACE}
```

## Customization

- **Change model**: Edit `ms-kv-events/values.yaml` and update the `modelArtifacts.uri`, `modelArtifacts.name` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
