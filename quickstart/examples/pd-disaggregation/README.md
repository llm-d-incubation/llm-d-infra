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

2. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart (from `/llm-d-infra/quickstart`):
```bash
export HF_TOKEN=$(YOUR_TOKEN)
./llmd-infra-installer.sh --namespace llm-d-pd -r infra-pd -j istio --disable-metrics-collection
```

> Note: if you are deploying Istio as the gateway, e.g. `--gateway istio`, then you will need to apply a `DestinationRule`:

```bash
kubectl apply -f destinationRule.yaml
```

3. Use the helmfile to apply the modelservice and GIE charts on top of it
```bash
helmfile --selector managedBy=helmfile apply helmfile.yaml --skip-diff-on-install
```

We can see that the charts were deployed:

```bash
helm list

>> NAME    	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART                    	APP VERSION
>> gaie-pd 	llm-d-pd 	1       	2025-07-24 03:34:09.947433488 +0000 UTC	deployed	inferencepool-v0.5.1     	v0.5.1
>> infra-pd	llm-d-pd 	2       	2025-07-24 03:37:29.976376182 +0000 UTC	deployed	llm-d-infra-1.0.7        	0.1
>> ms-pd   	llm-d-pd 	1       	2025-07-24 03:34:10.43345471 +0000 UTC 	deployed	llm-d-modelservice-0.0.19	0.0.1
```

We can see that 4 prefill replicas were created and 1 decode replica was created:

```bash
kubectl get pods

>> NAME                                                READY   STATUS    RESTARTS   AGE
>> gaie-pd-epp-55c5455dc5-jqh9r                        1/1     Running   0          28m
>> ms-pd-llm-d-modelservice-decode-8648644895-fz4bm    2/2     Running   0          28m
>> ms-pd-llm-d-modelservice-prefill-5cbb8c6dcc-48qg7   1/1     Running   0          3m19s
>> ms-pd-llm-d-modelservice-prefill-5cbb8c6dcc-7gfbs   1/1     Running   0          3m41s
>> ms-pd-llm-d-modelservice-prefill-5cbb8c6dcc-82b4g   1/1     Running   0          3m21s
>> ms-pd-llm-d-modelservice-prefill-5cbb8c6dcc-mvnmh   1/1     Running   0          3m41s
```
