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
- `gke`

Its important to note that here we are simply destinguishing the gateway providers with regard to information for installing the control plane. This is important because while the GKE provider supports two separate gatewayClassNames (`gke-17-externally-managed` and `gke-17-rilb`) those are configurations of the individual gateway and not the control plane as a whole.

## Installation

To Install the gateway control plane and corresponding CRDs you can use:

```bash
helmfile apply -e <your_gateway_choice> # options: [`istio`, `kgateway`, `gke`]
```

### Targeted install

If the CRDs already exist in your cluster and you do not wish to re-apply them, you use the `--selector kind=gateway-control-plane` selector to only apply or tear down the control plane, ex:

```bash
# Spin up
helmfile apply -e <your_gateway_choice> --selector kind=gateway-control-plane
# Tear down
helmfile destroy -e <your_gateway_choice> --selector kind=gateway-control-plane
```

If you wish to bump versions or customize your installs, check out our values files for [istio](./istio.yaml), [kgateway](./kgateway.yaml), and [gke](./gke.yaml) respectively.

### GKE Specific

If you are using GKE you should have your gateway control plane configured out of the box so you can skip the contents of this directory entirely.
