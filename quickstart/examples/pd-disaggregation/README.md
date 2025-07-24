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
export HF_TOKEN=$(YOUR_TOKEN)
./llmd-infra-installer.sh --namespace llm-d-pd -r infra-pd -f examples/pd-disaggregation/infra-pd/values.yaml --disable-metrics-collection
```

3. Use the helmfile to apply the modelservice and GIE charts on top of it
```bash
cd examples/pd-disaggregation
helmfile --selector managedBy=helmfile apply helmfile.yaml --skip-diff-on-install
```

> Note: When using Istio as the gateway, e.g. `--gateway istio`, you will need to apply a `DestinationRule` described in [Temporary Istio Workaround](../../istio-workaround.md).

We can see that the charts were deployed:

```bash
$ helm list
NAME    	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART                    	APP VERSION
gaie-pd 	llm-d-pd 	1       	2025-07-24 10:15:04.63662 -0700 PDT 	deployed	inferencepool-v0.5.1     	v0.5.1
infra-pd	llm-d-pd 	1       	2025-07-24 10:13:50.654169 -0700 PDT	deployed	llm-d-infra-1.0.8        	0.1
ms-pd   	llm-d-pd 	1       	2025-07-24 10:15:09.973653 -0700 PDT	deployed	llm-d-modelservice-0.0.19	0.0.1
```

We can see that 4 prefill replicas were created and 1 decode replica was created:

```bash
$ kubectl get pods
NAME                                                READY   STATUS    RESTARTS   AGE
gaie-pd-epp-69888bdd8d-6pnbk                        1/1     Running   0          54s
infra-pd-inference-gateway-istio-776797b79f-6clvr   1/1     Running   0          2m9s
ms-pd-llm-d-modelservice-decode-65f7f65cf6-2fh62    2/2     Running   0          50s
ms-pd-llm-d-modelservice-prefill-549598dd6c-6f757   1/1     Running   0          49s
ms-pd-llm-d-modelservice-prefill-549598dd6c-6n4bc   1/1     Running   0          49s
ms-pd-llm-d-modelservice-prefill-549598dd6c-ft89l   1/1     Running   0          49s
ms-pd-llm-d-modelservice-prefill-549598dd6c-pbjzx   1/1     Running   0          49s
```
