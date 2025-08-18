# Well-lit Path: Intelligent Inference Scheduling

## Overview

This example deploys the recommended out of the box [scheduling configuration](https://github.com/llm-d/llm-d-inference-scheduler/blob/main/docs/architecture.md) for most vLLM deployments, reducing tail latency and increasing throughput through load-aware and prefix-cache aware balancing. This can be run on a single GPU that can load [Qwen/Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B).

This profile defaults to the approximate prefix cache aware scorer, which only observes request traffic to predict prefix cache locality. The [precise prefix cache aware routing feature](../precise-prefix-cache-aware) improves hit rate by introspecting the vLLM instances for cache entries and will become the default in a future release.

### Pre-requisites

- It is assumed that you have the proper tools installed on your local system to use these quickstart. If you do not have these, see [install-deps.sh](../../install-deps.sh).

- It is also assumed you have the Gateway API installed in your cluster, for more information see their [project docs](https://gateway-api.sigs.k8s.io/) or their [github repo](https://github.com/kubernetes-sigs/gateway-api). For your convenience we have provided a 1 liner:

```bash
kubectl apply -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gateway-api
```

- You also need to install the Gateway-API-Inference-Extension CRDs. To do so you can use:

```bash
kubectl apply -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gie
```

- You must have the `llm-d-hf-token` secret in the namespace you want to deploy to with key `HF_TOKEN`. This should come as no supprise to our users, however since we have deprecated the `llmd-infra-installer.sh` you will now have to create this manually.

```bash
export NAMESPACE=llm-d-inference-scheduling # Or any namespace your heart desires
export HF_TOKEN=$(HFTOKEN)
kubectl create secret generic llm-d-hf-token \
    --from-literal="HF_TOKEN=${HF_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
```

## Installation

Use the helmfile to compose and install the stack. The Namespace in which the stack will be deployed will be derived from the `${NAMESPACE}` environment variable. If you have not set this, it will default to `llm-d-inference-scheduling` in this example.

```bash
export NAMESPACE=llm-d-inference-scheduling # Or any namespace your heart desires
cd quickstart/examples/inference-scheduling
helmfile apply --skip-diff-on-install
```

**_NOTE:_** This uses Istio as the default provider, see [Gateway Options](./README.md#gateway-options) for installing with a specific provider.

### Customizing your install

Want to only deploy the inferencing stack (Modelservice + GAIE + Infra charts) and not touch your gateway control plane (Istio, Kgateway, GKE, etc.)? Leverage our selectors built in to the helmfile:

```bash
helmfile apply --selector kind=inference-stack
```

Conversely if you just wanted to apply your gateway infrastructure you could do it like so:

```bash
helmfile apply --selector type=gateway-provider
```

#### Gateway options

Currently we support 3 gateway providers as `environments` in helmfile, those are `istio`, `kgateway` and `gke`. To install for that provider, simply pass the `-e <environment_name>` flag to your install as so:

```bash
# for kgateway:
helmfile apply -e kgateway --skip-diff-on-install
# for GKE:
helmfile apply -e gke --skip-diff-on-install
```

## Verify the Installation

1. Firstly, you should be able to list all helm releases to view the 3 charts got installed into the `llm-d-inference-scheduling` namespace:

```bash
helm list -n ${NAMESPACE}
NAME                        NAMESPACE                   REVISION  UPDATED                               STATUS    CHART                     APP VERSION
gaie-inference-scheduling   llm-d-inference-scheduling  1         2025-08-17 17:09:42.037517 -0700 PDT  deployed  inferencepool-v0.5.1      v0.5.1
infra-inference-scheduling  llm-d-inference-scheduling  1         2025-08-17 17:09:38.041567 -0700 PDT  deployed  llm-d-infra-v1.2.2        v0.2.0
ms-inference-scheduling     llm-d-inference-scheduling  1         2025-08-17 17:09:46.31162 -0700 PDT   deployed  llm-d-modelservice-v0.2.6 v0.2.0
```

1. Find the gateway service:

```bash
kubectl get services -n ${NAMESPACE}
NAME                                                 TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                        AGE
gaie-inference-scheduling-epp                        ClusterIP      172.30.135.125   <none>                                                                    9002/TCP,9090/TCP              27m
gaie-inference-scheduling-ip-18c12339                ClusterIP      None             <none>                                                                    54321/TCP                      27m
infra-inference-scheduling-inference-gateway-istio   LoadBalancer   172.30.244.141   aa34f27b0d58840c3b1d9ad77ffbb64a-1258197296.us-east-1.elb.amazonaws.com   15021:30096/TCP,80:32223/TCP   26m
```

In this case we have found that our gateway service is called `infra-inference-scheduling-inference-gateway`.

1. `port-forward` the service so we can curl it:

```bash
kubectl port-forward -n ${NAMESPACE} service/infra-inference-scheduling-inference-gateway-istio 8000:80
```

1. Try curling the `/v1/models` endpoint:

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1755478424,
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
          "created": 1755478424,
          "group": null,
          "id": "modelperm-0da9ea7786454927b90c0914b281fedd",
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
      "text": " I'm sorry, I can't respond to questions about your questions. It's a bit of a dilemma. I'm sorry for the confusion.\n\nBut I can help you with anything you need. Please let me know what you need help with. For"
    }
  ],
  "created": 1755478447,
  "id": "cmpl-b7c76172-ca13-4b8e-bf81-f3e4bebdb115",
  "kv_transfer_params": null,
  "model": "Qwen/Qwen3-0.6B",
  "object": "text_completion",
  "service_tier": null,
  "system_fingerprint": null,
  "usage": {
    "completion_tokens": 50,
    "prompt_tokens": 5,
    "prompt_tokens_details": null,
    "total_tokens": 55
  }
}
```

## Cleanup

To remove the deployment:

```bash
# Remove the model services
# From examples/inference-scheduling
helmfile --selector kind=inference-stack destroy

# Remove the infrastructure
helm uninstall infra-inference-scheduling -n ${NAMESPACE}
# Remove the other 2 release coordinated by helmfile
helm uninstall gaie-inference-scheduling -n ${NAMESPACE}
helm uninstall ms-inference-scheduling -n ${NAMESPACE}
```

> [!IMPORTANT]
> With the new `v0.3.0` install paradigmn, where we curry helmfiles together, if you do not use the `--selector kind=inference-stack` it will actually uninstall your gateway provider. THIS CAN BREAK OTHER INSTALLS IN YOUR CLUSTER! Be very mindufl of this when spinning down the stack.

## Customization

- **Change model**: Edit `ms-inference-scheduling/values.yaml` and update the `modelArtifacts.uri` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
