# Kgateway Production Example

  Production-ready Kgateway (Envoy Gateway) deployment.

  ## What This Deploys

  - Gateway (Kgateway, port 80, HTTP)
  - GatewayParameters (Envoy config with production resources)

  ## Prerequisites

  - Envoy Gateway (Kgateway) installed
  - Gateway class `kgateway` available

  ## Usage

  ```bash
  kubectl apply -k kustomize/examples/kgateway-production

  Verify

  kubectl get gateway,gatewayparameters -n llm-d-prod

  Customizations Applied

  - Namespace: llm-d-prod
  - Name prefix: prod-
  - Resource limits: 4 CPU, 2Gi memory
  - Envoy container security context

  Clean Up

  kubectl delete -k kustomize/examples/kgateway-production