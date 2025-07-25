# Well-lit Path: Wide Expert Parallelism (EP/DP) with LeaderWorkerSet

## Overview

- This example demonstrates how to deploy DeepSeek-R1-0528 using vLLM's P/D disaggregation support with NIXL in a wide expert parallel pattern with LeaderWorkerSets
- This "path" has been validated on a Cluster with 16xH200 GPUs split across two nodes with infiniband networking

> WARNING: We are still investigating and optimizing performance for other hardware and networking configurations

In this example, we will demonstrate a deployment of `DeepSeek-R1-0528` with:
- 1 DP=8 Prefill Workers
- 2 DP=4 Decode Worker

```bash
cd quickstart
HF_TOKEN=${HFTOKEN} ./llmd-infra-installer.sh --namespace llm-d-wide-ep -r infra-wide-ep -f examples/wide-ep-lws/infra-wide-ep/values.yaml --disable-metrics-collection
cd examples/wide-ep-lws
helmfile --selector managedBy=helmfile apply
```
