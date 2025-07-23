# Well-lit Path: Wide Expert Parallelism (EP/DP) with LeaderWorkerSet

## Overview

```bash

cd quickstart
HF_TOKEN=$(HFTOKEN) ./llmd-infra-installer.sh --namespace llm-d -r infra-wide-ep --disable-metrics-collection  -j istio # have to use istio in this example
cd examples/wide-ep-lws
helmfile --selector managedBy=helmfile apply
```
