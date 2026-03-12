# Istio Minimal Example

  Basic Istio gateway deployment with default settings.

  ## What This Deploys

  - Gateway (Istio, port 80, HTTP)
  - ConfigMap (Istio proxy configuration)
  - Telemetry (Istio access logging)

  ## Usage
  ```bash
  kubectl apply -k kustomize/examples/istio-minimal
  ```
  
  ## Verify
  ```bash
  kubectl get gateway,configmap,telemetry -n llm-d
  ```
  
  ## Clean Up
  ```bash
  kubectl delete -k kustomize/examples/istio-minimal
  ```
  
  ## When to Use

  - Development environments
  - Internal cluster access only
  - No external Ingress needed
  - Default resource limits acceptable