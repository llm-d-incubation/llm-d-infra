# Istio with TLS Example

  Production Istio gateway with HTTPS/TLS termination.

  ## What This Deploys

  - Gateway (Istio, HTTP port 80 + HTTPS port 443)
  - ConfigMap (Istio proxy configuration)
  - Telemetry (Istio access logging)
  - TLS listener on port 443

  ## Prerequisites

  - Istio installed
  - TLS certificate and key for your domain

  ## Create TLS Secret

  **Before deploying**, create a TLS Secret with your certificate:

  ```bash
  # From certificate files
  kubectl create secret tls llm-d-tls-cert \
    --cert=path/to/tls.crt \
    --key=path/to/tls.key \
    -n llm-d-prod

  # OR from cert-manager (automated)
  # See: https://cert-manager.io/docs/

  Customize Domain

  Edit kustomization.yaml and change the hostname:

  patches:
    - patch: |-
        - op: replace
          path: /spec/listeners/1/hostname
          value: api.example.com  # <-- Change this to your domain

  Usage

  # Deploy (ensure TLS secret exists first!)
  kubectl apply -k kustomize/examples/istio-with-tls

  Verify

  # Check Gateway
  kubectl get gateway -n llm-d-prod

  # Verify listeners (should show both HTTP:80 and HTTPS:443)
  kubectl get gateway prod-llm-d-gateway -n llm-d-prod -o yaml | grep -A 10 "listeners:"

  Access

  # HTTP (port 80)
  curl http://api.example.com/v1/chat/completions

  # HTTPS (port 443)
  curl https://api.example.com/v1/chat/completions

  HTTPRoute Configuration

  Your HTTPRoutes should reference the HTTPS listener:

  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: llm-d-route
  spec:
    parentRefs:
      - name: prod-llm-d-gateway
        sectionName: https  # Reference the HTTPS listener
    rules:
      - matches:
          - path:
              value: /v1/chat/completions
        backendRefs:
          - name: inference-service
            port: 8000

  HTTP to HTTPS Redirect (Optional)

  To redirect HTTP → HTTPS, create an HTTPRoute:

  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: http-redirect
  spec:
    parentRefs:
      - name: prod-llm-d-gateway
        sectionName: http
    rules:
      - filters:
          - type: RequestRedirect
            requestRedirect:
              scheme: https
              statusCode: 301

  Clean Up

  kubectl delete -k kustomize/examples/istio-with-tls
  kubectl delete secret llm-d-tls-cert -n llm-d-prod

  Using cert-manager (Recommended for Production)

  Instead of manually creating secrets, use cert-manager:

  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: llm-d-tls-cert
    namespace: llm-d-prod
  spec:
    secretName: llm-d-tls-cert
    issuerRef:
      name: letsencrypt-prod
      kind: ClusterIssuer
    dnsNames:
      - api.example.com

  cert-manager will automatically create and renew the TLS secret.