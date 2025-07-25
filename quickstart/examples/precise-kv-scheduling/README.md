# Feature: Precise Prefix Cache Aware Scheduling

## Overview

This is a simple quickstart demonstrating how to configure the inference scheduler to use the new precise prefix cache aware scheduling based on [vLLM KV-Events](https://github.com/vllm-project/vllm/issues/16669) data. Precise prefix cache aware scheduling pulls up-to-date prefix cache status from serving instances, eliminating the need for additional indexing services and increasing cache hit rate at high throughput.

## Installation

> To adjust the model or any other modelservice values, simply change the values.yaml file in [ms-precise-kv-scheduling/values.yaml](ms-precise-kv-scheduling/values.yaml)
>
> Note that the decode vLLM container `--prefix-caching-hash-algo` argument must not change

1. Install the dependencies; see [install-deps.sh](../../../../../../llm-d-incubation/llm-d-infra/quickstart/install-deps.sh)
2. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart:

```bash
# From the repo root
cd quickstart
export HF_TOKEN=${HFTOKEN}
./llmd-infra-installer.sh --namespace llm-d-precise-kv-scheduling -r infra-precise-kv-scheduling --gateway kgateway --disable-metrics-collection
```
    - It should be noted release name `infra-precise-kv-scheduling` is important here, because it matches up with pre-built values files used in this example.

3. Use the helmfile to apply the modelservice and GIE charts on top of it.

```bash
cd examples/precise-prefix-cache-aware
helmfile --selector managedBy=helmfile apply helmfile.yaml --skip-diff-on-install
```

## Verify the Installation

1. Firstly, you should be able to list all helm releases in the `llm-d-precise-kv-scheduling` ns to view all 3 charts that should be installed:

```bash
$ helm list -n llm-d-precise-kv-scheduling --all --debug helm list -n llm-d-precise-kv-scheduling --all --debug
NAME                       	NAMESPACE                  	REVISION	UPDATED                             	STATUS  	CHART                    	APP VERSION
gaie-precise-kv-scheduling 	llm-d-precise-kv-scheduling	1       	2025-07-25 08:18:06.802006 -0700 PDT	deployed	inferencepool-v0.5.1     	v0.5.1
infra-precise-kv-scheduling	llm-d-precise-kv-scheduling	1       	2025-07-25 08:17:07.916991 -0700 PDT	deployed	llm-d-infra-1.0.9        	0.1
ms-precise-kv-scheduling   	llm-d-precise-kv-scheduling	1       	2025-07-25 08:18:11.908269 -0700 PDT	deployed	llm-d-modelservice-0.0.19	0.0.1
```

Note: if you chose to use `istio` as your Gateway provider you would see those (`istiod` and `istio-base` in the `istio-system` namespace) instead of the kgateway based ones.

2. Find the gateway service:
```bash
$ kubectl get services -n llm-d-precise-kv-scheduling
NAME                                            TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
gaie-precise-kv-scheduling-epp                  ClusterIP   10.16.0.211   <none>        9002/TCP,9090/TCP,5557/TCP   9m59s
infra-precise-kv-scheduling-inference-gateway   NodePort    10.16.2.153   <none>        80:30849/TCP                 10m
```
In this case we have found that our gateway service is called `infra-precise-kv-scheduling-inference-gateway`.

3. `port-forward` the service to we can curl it:

```bash
kubectl -n llm-d-precise-kv-scheduling port-forward service/infra-precise-kv-scheduling-inference-gateway 8000:80
```

4. Try curling the `/v1/models` endpoint:

```bash
curl http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
```
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   484    0   484    0     0   1903      0 --:--:-- --:--:-- --:--:--  1905
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

5. Curl the `v1/completions` endpoint once:
```bash
export LONG_TEXT_200_WORDS="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." && \
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-0.6B",
    "prompt": "'"$LONG_TEXT_200_WORDS"'",
    "max_tokens": 50
  }' | jq
```
```yaml
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   662    0   566  100    96   1088    184 --:--:-- --:--:-- --:--:--  1273
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
  "created": 1752876024,
  "id": "cmpl-0e08703d-30c0-4624-a7b3-31e94dc99bc8",
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

6. Check the inference-scheduler's prefix-cache-scorer's scores with the following command:
```bash
kubectl logs -l inferencepool=gaie-precise-kv-scheduling-epp -n llm-d-precise-kv-scheduling --tail 100 | grep "Got pod scores"
```

You should see output similar to:
```bash
2025-07-18T22:00:24Z    LEVEL(-4)       prefix-cache-scorer/prefix-cache-scorer scorer/prefix_cache_tracking.go:133     Got pod scores  {"x-request-id": "0e08703d-30c0-4624-a7b3-31e94dc99bc8", "model": "Qwen/Qwen3-0.6B", "resolvedTargetModel": "Qwen/Qwen3-0.6B", "criticality": "Sheddable", "scores": null}
```

7. Repeat steps 5 and 6 to see the prefix-cache-scorer in action

You should see output similar to:
```log
2025-07-18T22:00:24Z    LEVEL(-4)       prefix-cache-scorer/prefix-cache-scorer scorer/prefix_cache_tracking.go:133     Got pod scores  {"x-request-id": "0e08703d-30c0-4624-a7b3-31e94dc99bc8", "model": "Qwen/Qwen3-0.6B", "resolvedTargetModel": "Qwen/Qwen3-0.6B", "criticality": "Sheddable", "scores": null}
2025-07-18T22:00:46Z    LEVEL(-4)       prefix-cache-scorer/prefix-cache-scorer scorer/prefix_cache_tracking.go:133     Got pod scores  {"x-request-id": "8d0b587d-058f-4d2e-a062-a859a565d37a", "model": "Qwen/Qwen3-0.6B", "resolvedTargetModel": "Qwen/Qwen3-0.6B", "criticality": "Sheddable", "scores": {"${POD_IP}":2}}
```

Notice that the second time we called the `/v1/completions` endpoint, the prefix-cache-scorer was able to return a score for the pod,
indicating that it had cached the KV-blocks from the first call.

8. See the `kvblock.Index` metrics in the `gaie-precise-kv-scheduling-epp` pod:
```bash
kubectl logs -l inferencepool=gaie-precise-kv-scheduling-epp -n llm-d-precise-kv-scheduling --tail 100 | grep "metrics beat"
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
helmfile --selector managedBy=helmfile destroy

# Remove the infrastructure
helm uninstall infra-precise-kv-scheduling -n llm-d-precise-kv-scheduling
```

## Customization

- **Change model**: Edit `ms-precise-kv-scheduling/values.yaml` and update the `modelArtifacts.uri` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
