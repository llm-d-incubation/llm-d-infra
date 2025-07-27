# Well-lit Path: P/D Disaggregation

## Overview

- This example demonstrates how to deploy Llama-70B using vLLM's P/D disaggregation support with NIXL
- This "path" has been validated on an 8xH200 cluster with infiniband networking

> WARNING: We are still investigating and optimizing performance for other hardware and networking configurations

In this example, we will demonstrate a deployment of `Llama-3.3-70B-Instruct-Fp8` with:
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

As a result, as you tune you P/D deployments, we suggest focusing on the following parameters:
- **Heterogenous Parallelism**: deploy P workers with less parallelism and more replicas and D workers with more parallelism and fewer replicas
- **xPyD Ratios**: tuning the ratio of P workers to D workers to ensure balance for your ISL|OSL ratio

## Installation

1. Install your local dependencies (from `/llm-d-infra/quickstart`)

```bash
./install-deps.sh
```

2. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart (from `/llm-d-infra/quickstart`). This example only works out of the box with `Istio` as a provider, but with changes its possible to run this with `kgateway`.

```bash
# ran from root of repo
cd quickstart
export HF_TOKEN=$(HFTOKEN)
./llmd-infra-installer.sh --namespace llm-d-pd -r infra-pd -f examples/pd-disaggregation/infra-pd/values.yaml --disable-metrics-collection
```

**_NOTE:_** The release name `infra-pd` is important here, because it matches up with pre-built values files used in this example.

3. Use the helmfile to apply the modelservice and GIE charts on top of it
```bash
cd examples/pd-disaggregation
helmfile --selector managedBy=helmfile apply -f helmfile.yaml --skip-diff-on-install
```

## Verifying the installation

1. First lets check that all three charts were deployed successfully to our `llm-d-pd` namespace:

```bash
$ helm list -n llm-d-pd
NAME    	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART                   	APP VERSION
gaie-pd 	llm-d-pd 	1       	2025-07-25 11:27:47.419598 -0700 PDT	deployed	inferencepool-v0.5.1    	v0.5.1
infra-pd	llm-d-pd 	1       	2025-07-25 11:27:18.453254 -0700 PDT	deployed	llm-d-infra-v1.1.0      	v0.2.0
ms-pd   	llm-d-pd 	1       	2025-07-25 11:27:53.138175 -0700 PDT	deployed	llm-d-modelservice-0.2.0	v0.2.0
```

2. Next lets check our pod health of our 4 prefill replicas and 1 decode replica:

```bash
$ kubectl get pods -n llm-d-pd
NAME                                                READY   STATUS    RESTARTS   AGE
gaie-pd-epp-69888bdd8d-6pnbk                        1/1     Running   0          54s
infra-pd-inference-gateway-istio-776797b79f-6clvr   1/1     Running   0          2m9s
ms-pd-llm-d-modelservice-decode-65f7f65cf6-2fh62    2/2     Running   0          50s
ms-pd-llm-d-modelservice-prefill-549598dd6c-6f757   1/1     Running   0          49s
ms-pd-llm-d-modelservice-prefill-549598dd6c-6n4bc   1/1     Running   0          49s
ms-pd-llm-d-modelservice-prefill-549598dd6c-ft89l   1/1     Running   0          49s
ms-pd-llm-d-modelservice-prefill-549598dd6c-pbjzx   1/1     Running   0          49s
```

3. Find the gateway service:
```bash
$ kubectl get services -n llm-d-pd
NAME                               TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                        AGE
gaie-pd-epp                        ClusterIP   10.16.0.161   <none>        9002/TCP,9090/TCP              6m6s
gaie-pd-ip-bb618139                ClusterIP   None          <none>        54321/TCP                      6m1s
infra-pd-inference-gateway-istio   NodePort    10.16.0.146   <none>        15021:34743/TCP,80:30212/TCP   6m36s
```
In this case we have found that our gateway service is called `infra-pd-inference-gateway-istio`.

4. `port-forward` the service to we can curl it:

```bash
kubectl port-forward -n llm-d-pd service/infra-pd-inference-gateway-istio 8000:80
```

5. Try curling the `/v1/models` endpoint:

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1753468493,
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
          "created": 1753468493,
          "group": null,
          "id": "modelperm-df4f0c7555e648fe82a3a952d0634e20",
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

6. Try curling the `v1/completions` endpoint:
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
      "text": " I hope you are having a great day so far. I just wanted to remind you that you are not alone. No matter what you are going through, you have people who care about you and want to help.\nIf you are struggling with difficult emotions"
    }
  ],
  "created": 1753468566,
  "id": "cmpl-e18c8248-bcd7-4c26-a7fc-a7e214dc3ff1",
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
helmfile --selector managedBy=helmfile destroy -f helmfile.yaml

# Remove the infrastructure
helm uninstall infra-pd -n llm-d-pd
```

## Customization

- **Change model**: Edit `ms-pd/values.yaml` and update the `modelArtifacts.uri` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
