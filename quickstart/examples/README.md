# LLM-D-Infra quickstart

This document should walk through how people consume llm-d-infra, as well as examples for composing it with modelservice charts and or upstream GAIE.

## Getting started

- First, Lets patch our `HF_TOKEN` into the `extraDeploy` section of the values for the chart, so it can create a secret to hold our `HF_TOKEN`

```bash
yq eval '.extraDeploy[0].data.HF_TOKEN = (strenv(HF_TOKEN) | @base64)' llm-d-infra/istio-values.template.yaml > llm-d-infra/istio-values.yaml
```

- Second, we can simply apply the helmfile composing installations of the different charts

```bash
helmfile apply helmfile.yaml
```

## Taking it down

To remove all the helm release installations you can simply:

```bash
helmfile destroy helmfile.yaml
```
