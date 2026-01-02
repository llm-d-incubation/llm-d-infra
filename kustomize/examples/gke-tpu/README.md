# GKE TPU Example

  GKE L7 gateway optimized for TPU-based LLM inference workloads.

  ## What This Deploys

  - Gateway (GKE L7, port 80, HTTP)
  - Labels indicating TPU workload type
  - GKE-specific annotations for TPU optimization

  ## Prerequisites

  - GKE cluster with TPU node pools
  - Gateway API enabled
  - Gateway class `gke-l7-regional-external-managed` available

  ## Enable Gateway API on GKE

  ```bash
  gcloud container clusters update CLUSTER_NAME \
    --gateway-api=standard \
    --region=REGION

  Create TPU Node Pool

  gcloud container node-pools create tpu-pool \
    --cluster=CLUSTER_NAME \
    --machine-type=ct5lp-hightpu-4t \
    --num-nodes=1 \
    --region=REGION
  ```
  ## Usage
  ```bash
  kubectl apply -k kustomize/examples/gke-tpu
  
  #Verify

  kubectl get gateway -n llm-d

  # Check for external IP (takes a few minutes)
  kubectl get gateway llm-d-gateway -n llm-d -o jsonpath='{.status.addresses[0].value}'

  # Verify TPU labels
  kubectl get gateway llm-d-gateway -n llm-d -o jsonpath='{.metadata.labels}'

  Access

  Once the gateway has an external IP:

  GATEWAY_IP=$(kubectl get gateway llm-d-gateway -n llm-d -o jsonpath='{.status.addresses[0].value}')
  curl http://$GATEWAY_IP/v1/chat/completions
  ```
  
  ## Clean Up
  ``` bash
  kubectl delete -k kustomize/examples/gke-tpu
  ```
  
  ## Differences from Standard GKE

  | Feature        | Standard GKE | GKE-TPU                          |
  |----------------|--------------|----------------------------------|
  | Labels         | Basic        | + TPU workload labels            |
  | Annotations    | Minimal      | + NEG, backend config            |
  | Backend Config | Optional     | Recommended for TPU optimization |
  | Node Affinity  | Any          | TPU node pools                   |

  ## Related

  - https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api
  - https://cloud.google.com/kubernetes-engine/docs/how-to/tpus
  - https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features