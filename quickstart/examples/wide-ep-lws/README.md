# Well-lit Path: Wide Expert Parallelism (EP/DP) with LeaderWorkerSet

## Overview

```bash
cd quickstart
HF_TOKEN=${HFTOKEN} ./llmd-infra-installer.sh --namespace llm-d-wide-ep -r infra-wide-ep -f examples/wide-ep-lws/infra-wide-ep/values.yaml --disable-metrics-collection
cd examples/wide-ep-lws
helmfile --selector managedBy=helmfile apply
```
