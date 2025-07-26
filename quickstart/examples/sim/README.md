# Feature: llm-d Simulation

## Overview

This is a simulation example that demonstrates how to deploy using the llm-d-infra system with the `ghcr.io/llm-d/llm-d-inference-sim` image. This example simulates inference responses and can run on minimal resources without requiring actual GPU hardware.

### EPP Image Compatibility

As documented in the [GIE values file](./gaie-sim/values.yaml#L4-L13), either the upstream EPP GIE image or the midstream `llm-d-inference-scheduler` image will for EPP.

## Installation

> To adjust the simulation settings or any other modelservice values, simply change the values.yaml file in [ms-llm-d-sim/values.yaml](ms-llm-d-sim/values.yaml)

1. Install the dependencies; see [install-deps.sh](../../install-deps.sh)
2. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart:

```bash
# From the repo root
cd quickstart
export HF_TOKEN=${HFTOKEN}
./llmd-infra-installer.sh --namespace llm-d-sim -r infra-sim --gateway kgateway --disable-metrics-collection
```

**_NOTE:_** The release name `infra-sim` is important here, because it matches up with pre-built values files used in this example.


3. Use the helmfile to apply the modelservice and GIE charts on top of it.

```bash
cd examples/sim
helmfile --selector managedBy=helmfile apply -f helmfile.yaml --skip-diff-on-install
```

**_NOTE:_** This examples was built with `kgateway` in mind. If you are deploying Istio as the gateway, e.g. `--gateway istio`, then you will need to apply a `DestinationRule` described in [Temporary Istio Workaround](../../istio-workaround.md).

## Verify the Installation

1. Firstly, you should be able to list all helm releases to view all charts that should be installed:

```bash
$ helm list -n llm-d-sim --all --debug
NAME     	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART                   	APP VERSION
gaie-sim 	llm-d-sim	1       	2025-07-25 10:39:08.317195 -0700 PDT	deployed	inferencepool-v0.5.1    	v0.5.1
infra-sim	llm-d-sim	1       	2025-07-25 10:38:48.360829 -0700 PDT	deployed	llm-d-infra-v1.1.0      	v0.2.0
ms-sim   	llm-d-sim	1       	2025-07-25 10:39:15.127738 -0700 PDT	deployed	llm-d-modelservice-0.2.0	v0.2.0
```

Note: if you chose to use `istio` as your Gateway provider you would see those (`istiod` and `istio-base` in the `istio-system` namespace) instead of the kgateway based ones.

2. Find the gateway service:

```bash
$ kubectl get services -n llm-d-simget services -n llm-d-sim
NAME                          TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)             AGE
gaie-sim-epp                  ClusterIP   10.16.2.6     <none>        9002/TCP,9090/TCP   42s
infra-sim-inference-gateway   NodePort    10.16.2.157   <none>        80:37479/TCP        64s
```

In this case we have found that our gateway service is called `infra-sim-inference-gateway`.

3. `port-forward` the service to we can curl it:

```bash
kubectl port-forward -n llm-d-sim service/infra-sim-inference-gateway 8000:80
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
helmfile --selector managedBy=helmfile destroy -f helmfile.yaml

# Remove the infrastructure
helm uninstall infra-sim -n llm-d-sim
```

## Customization

- **Change simulation behavior**: Edit `ms-llm-d-sim/values.yaml` and update the simulation parameters
- **Adjust resources**: Modify the CPU/memory requests in the container specifications (no GPU required for simulation)
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
- **Different model simulation**: Update `routing.modelName` to simulate different model names
