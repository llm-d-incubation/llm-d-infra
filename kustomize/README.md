# llm-d-infra Kustomize

  Kustomize-based deployment for llm-d gateway infrastructure.

  ## Quick Start

  Choose a gateway provider and deploy:

  ```bash
  # Istio (default)
  kubectl apply -k kustomize/overlays/istio

  # Kgateway (Envoy Gateway)
  kubectl apply -k kustomize/overlays/kgateway

  # GKE L7 Regional External
  kubectl apply -k kustomize/overlays/gke

  Directory Structure

  kustomize/
  ├── base/                  # Common Gateway resource
  ├── overlays/              # Gateway provider variants
  │   ├── istio/            # Istio gateway
  │   ├── kgateway/         # Kgateway (Envoy Gateway)
  │   └── gke/              # GKE L7 gateway
  ├── components/            # Optional features
  │   ├── ingress/          # External Ingress
  │   └── tls/              # HTTPS/TLS support
  └── examples/              # Production-ready configurations
      ├── istio-minimal/
      ├── istio-with-ingress/
      ├── istio-with-tls/
      ├── kgateway-production/
      └── gke-minimal/

  Usage Patterns

  Basic Development Setup

  kubectl apply -k kustomize/overlays/istio

  Production with Ingress

  kubectl apply -k kustomize/examples/istio-with-ingress

  Production with TLS

  # Create TLS secret first
  kubectl create secret tls llm-d-tls-cert \
    --cert=tls.crt --key=tls.key -n llm-d-prod

  # Deploy
  kubectl apply -k kustomize/examples/istio-with-tls

  Customization Guide

  Change Namespace

  # your-deployment/kustomization.yaml
  resources:
    - ../kustomize/overlays/istio

  namespace: my-namespace

  Add Name Prefix

  namePrefix: dev-

  Add Labels

  commonLabels:
    environment: production
    team: ml-platform

  Change Service Type to LoadBalancer

  For Istio:
  patches:
    - patch: |-
        - op: replace
          path: /data/service
          value: |
            spec:
              type: LoadBalancer
      target:
        kind: ConfigMap
        name: llm-d-gateway

  For Kgateway:
  patches:
    - patch: |-
        - op: replace
          path: /spec/kube/service/type
          value: LoadBalancer
      target:
        kind: GatewayParameters

  Add Custom Listeners

  patches:
    - patch: |-
        - op: add
          path: /spec/listeners/-
          value:
            name: metrics
            port: 9090
            protocol: HTTP
            allowedRoutes:
              namespaces:
                from: Same
      target:
        kind: Gateway

  Increase Resource Limits

  See examples/istio-with-ingress for pattern of replacing ConfigMap with production version.

  Add Annotations

  patches:
    - patch: |-
        - op: add
          path: /metadata/annotations
          value:
            prometheus.io/scrape: "true"
            prometheus.io/port: "9090"
      target:
        kind: Gateway

  Components

  Components are optional features you can mix and match:

  # your-deployment/kustomization.yaml
  resources:
    - ../kustomize/overlays/istio

  components:
    - ../kustomize/components/ingress  # Add external Ingress
    - ../kustomize/components/tls      # Add HTTPS listener
  
   Examples Explained

  | Example | Gateway Provider | Use Case | Features |
  |---------|-----------------|----------|----------|
  | `istio-minimal` | Istio | Development, basic setup | ConfigMap + Telemetry |
  | `istio-with-ingress` | Istio | Production, external access | + Ingress + Production resources |
  | `istio-with-tls` | Istio | Production, HTTPS | + TLS listener (port 443) |
  | `kgateway-production` | Kgateway | Production, Envoy Gateway | GatewayParameters + Production resources |
  | `gke-minimal` | GKE | GKE clusters | Minimal GKE setup |
  | `gke-tpu` | GKE | GKE with TPU workloads | TPU labels + annotations |

  Testing Your Configuration

  # Preview what will be deployed
  kubectl kustomize kustomize/examples/istio-with-tls

  # Save output for inspection
  kubectl kustomize kustomize/overlays/istio > /tmp/gateway.yaml

  Troubleshooting

  Gateway not getting IP address:
  - Check gateway class is installed: kubectl get gatewayclass
  - Check gateway status: kubectl describe gateway -n llm-d

  ConfigMap not applied:
  - Verify parametersRef points to correct ConfigMap
  - Check ConfigMap exists: kubectl get configmap -n llm-d

  TLS not working:
  - Verify TLS secret exists: kubectl get secret llm-d-tls-cert -n llm-d-prod
  - Check certificate is valid: kubectl get secret llm-d-tls-cert -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text