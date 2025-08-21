# Gateway Providers

This document will help walk you through choices around your gateway provider.

## Pre-requisites

Prior to applying your Gateway Control Plane infrastructure, there are two dependencies:

- [Gateway API v1.3.0 CRDs](https://github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.3.0)
  - for more information see their [docs](https://gateway-api.sigs.k8s.io/guides/)
- [Gateway API Inference Extension CRDs v0.5.1](https://github.com/kubernetes-sigs/gateway-api-inference-extension/config/crd?ref=v0.5.1)
  - for more information see their [docs](https://gateway-api-inference-extension.sigs.k8s.io/)

We have provided you the [`install-gateway-provider-dependencies.sh`](./install-gateway-provider-dependencies.sh) script to facilitate this, so feel free to run that as so:

```bash
./install-gateway-provider-dependencies.sh
```

It supports both installation by default, but also teardown as \`$1\`: `./install-gateway-provider-dependencies.sh delete`.

Additionally you can specify any valid git ref for versions as `GATEWAY_API_CRD_REVISION` and `GATEWAY_API_INFERENCE_EXTENSION_CRD_REVISION` respectively, ex:

```bash
export GATEWAY_API_CRD_REVISION="v1.2.0"
export GATEWAY_API_INFERENCE_EXTENSION_CRD_REVISION="v0.5.0"
./install-gateway-provider-dependencies.sh
```

## Supported Providers

This section will cover what Gateway Control Plane providers are supported. Currently that list is:

- `kgateway`
- `istio`
- `gke` *

> [!IMPORTANT]
> While LLM-D supports GKE Gateways, it comes setup out of the box on GKE, and so no action is required to deploy the control plane. If you are using GKE you may skip this document.

## Installation

To Install the gateway control plane and corresponding CRDs you can use:

```bash
helmfile apply -f <your_gateway_choice>.helmfile.yaml # options: [`istio`, `kgateway`]
# ex: helmfile apply -f istio.helmfile.yaml
```

### Targeted install

If the CRDs already exist in your cluster and you do not wish to re-apply them, you use the `--selector kind=gateway-control-plane` selector to only apply or tear down the control plane, ex:

```bash
# Spin up
helmfile apply -f <your_gateway_choice> --selector kind=gateway-control-plane
# Tear down
helmfile destroy -f <your_gateway_choice> --selector kind=gateway-control-plane
```

If you wish to bump versions or customize your installs, check out our helmfiles for [istio](./istio.helmfile.yaml), and [kgateway](./kgateway.helmfile.yaml) respectively.
