# Interactive Benchmark

This example shows some utilities for interacting with a running `llm-d` deployment.

> WARNING: this example assumes you have an `llm-d` deployment running

### 1. Create the interactive pod

```bash
NAMESPACE="llm-d"

just start-bench $NAMESPACE
```

### 2. Get the address of the gateway

```bash
kubectl get gatways

>> NAME                         CLASS      ADDRESS       PROGRAMMED   AGE
>> infra-pd-inference-gateway   kgateway   10.16.0.216   True         7m49s
```

### 3. Exec into the pod and run a benchmark

```bash
NAMESPACE="llm-d"

just exec-bench $NAMESPACE
```

#### Eval

- From within the pod, run the following to run `lm-eval`:

```bash
MODEL=RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic
NAMESPACE=llm-d
GATEWAY_URL=http://10.16.0.216
CONCURRENT=100
LIMIT=1000

just eval $MODEL $GATEWAY_URL $CONCURRENT $LIMIT

>> |Tasks|Version|     Filter     |n-shot|  Metric   |   |Value|   |Stderr|
>> |-----|------:|----------------|-----:|-----------|---|----:|---|-----:|
>> |gsm8k|      3|flexible-extract|     5|exact_match|↑  |0.938|±  |0.0076|
>> |     |       |strict-match    |     5|exact_match|↑  |0.908|±  |0.0091|
```

#### Benchmark

- From within the pod, run the following to sweep over concurrencies (modify `./sweep.sh` to edit the scenario):

```bash
MODEL=RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic
NAMESPACE=llm-d
GATEWAY_URL=http://10.16.0.216
OUTFILE=results.json

just sweep $MODEL $OUTFILE $GATEWAY_URL
```

- You can copy over the results with:

```bash
NAMESPACE=llm-d
OUTFILE=results.json

just copy-results $NAMESPACE $OUTFILE
```
