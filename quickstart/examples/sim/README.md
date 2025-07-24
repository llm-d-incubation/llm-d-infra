# Feature: llm-d Simulation

## Overview

This is a simulation example that demonstrates how to deploy using the llm-d-infra system with the `ghcr.io/llm-d/llm-d-inference-sim` image. This example simulates inference responses and can run on minimal resources without requiring actual GPU hardware.

## Installation

> To adjust the simulation settings or any other modelservice values, simply change the values.yaml file in [ms-llm-d-sim/values.yaml](ms-llm-d-sim/values.yaml)

1. Install the dependencies; see [install-deps.sh](../../install-deps.sh)
2. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart:

```bash
# From the repo root
cd quickstart
HF_TOKEN=$(HFTOKEN) ./llmd-infra-installer.sh --namespace llm-d -r sim --gateway kgateway
```

    - It should be noted release name `sim` is important here, because it matches up with pre-built values files used in this example.

3. Use the helmfile to apply the modelservice and GIE charts on top of it.

```bash
cd examples/sim
helmfile --selector managedBy=helmfile apply helmfile.yaml
```

---

> Note: if you are deploying Istio as the gateway, e.g. `--gateway istio`, then you will need to apply a `DestinationRule` described in [Temporary Istio Workaround](../../istio-workaround.md).

## Verify the Installation

1. Firstly, you should be able to list all helm releases to view all charts that should be installed:

```bash
helm list --all-namespaces --all --debug
```

Note: if you chose to use `istio` as your Gateway provider you would see those (`istiod` and `istio-base` in the `istio-system` namespace) instead of the kgateway based ones.

2. Find the gateway service:

```bash
kubectl get services
NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
gaie-sim-epp                  ClusterIP   10.101.43.58    <none>        9002/TCP,9090/TCP   29m
infra-sim-inference-gateway   NodePort    10.104.22.184   <none>        80:31233/TCP        95m
```

In this case we have found that our gateway service is called `sim-inference-gateway`.

3. `port-forward` the service to we can curl it:

```bash
kubectl port-forward service/sim-inference-gateway 8000:80
```

4. Try curling the `/v1/models` endpoint:

```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1752727169,
      "id": "random",
      "object": "model",
      "owned_by": "vllm",
      "parent": null,
      "root": "random"
    },
    {
      "created": 1752727169,
      "id": "",
      "object": "model",
      "owned_by": "vllm",
      "parent": "random",
      "root": ""
    }
  ],
  "object": "list"
}
```

5. Try curling the `v1/chat/completions` endpoint:

```bash
curl -X POST http://localhost:8000/v1/completions \
-H 'Content-Type: application/json' \
-d '{
      "model": "random",
      "prompt": "How are you today?"
    }' | jq
{
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "Today is a nice sunny day.",
        "role": "assistant"
      }
    }
  ],
  "created": 1752727735,
  "id": "chatcmpl-af42e9e3-dab0-420f-872b-d23353d982da",
  "model": "random"
}
```

## Cleanup

To remove the deployment:

```bash
# Remove the model services
# From examples/sim
helmfile --selector managedBy=helmfile destroy

# Remove the infrastructure
helm uninstall sim -n llm-d
```

## Customization

- **Change simulation behavior**: Edit `ms-llm-d-sim/values.yaml` and update the simulation parameters
- **Adjust resources**: Modify the CPU/memory requests in the container specifications (no GPU required for simulation)
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
- **Different model simulation**: Update `routing.modelName` to simulate different model names
