# GKE Minimal Example

  Basic GKE L7 Regional External Managed gateway deployment.

  ## What This Deploys

  - Gateway (GKE, port 80, HTTP)

  **Note:** GKE gateways do NOT require ConfigMap or GatewayParameters - GKE manages the infrastructure automatically.

  ## Prerequisites

  - GKE cluster with Gateway API enabled
  - Gateway class `gke-l7-regional-external-managed` available

  ## Enable Gateway API on GKE

  ```bash
  gcloud container clusters update CLUSTER_NAME \
    --gateway-api=standard \
    --region=REGION

  Usage

  kubectl apply -k kustomize/examples/gke-minimal

  Verify

  kubectl get gateway -n llm-d

  # Check for external IP (takes a few minutes)
  kubectl get gateway llm-d-gateway -n llm-d -o jsonpath='{.status.addresses[0].value}'

  Access

  Once the gateway has an external IP:

  GATEWAY_IP=$(kubectl get gateway llm-d-gateway -n llm-d -o jsonpath='{.status.addresses[0].value}')
  curl http://$GATEWAY_IP/v1/chat/completions

  Clean Up

  kubectl delete -k kustomize/examples/gke-minimal