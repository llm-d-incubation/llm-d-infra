# Istio with Ingress Example

  Production-ready Istio gateway with external Ingress for public access.

  ### What This Deploys

  - Gateway (Istio, port 80, HTTP)
  - ConfigMap (Istio proxy with production resource limits)
  - Telemetry (Istio access logging)
  - Ingress (nginx, hostname: llm-d.example.com)

  ### Prerequisites

  - Nginx Ingress Controller installed
  - DNS configured for llm-d.example.com

  ### Usage


  ```
  # Customize the hostname first
  vim kustomize/examples/istio-with-ingress/kustomization.yaml
  # Change llm-d.example.com to your domain
  ```
  
  #### Deploy
  ```
  kubectl apply -k kustomize/examples/istio-with-ingress
  ```

  #### Verify

  ```
  kubectl get gateway,configmap,telemetry,ingress -n llm-d-prod
  ```

  #### Access

  curl http://llm-d.example.com/v1/chat/completions

  ### Customizations Applied

  - Namespace: llm-d-prod
  - Name prefix: prod-
  - Ingress hostname: llm-d.example.com (change this!)
  - Resource limits: 4 CPU, 2Gi memory (production-sized)

  ### Clean Up
  ```
  kubectl delete -k kustomize/examples/istio-with-ingress
  ```