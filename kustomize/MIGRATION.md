This guide helps you migrate from Helm to Kustomize for llm-d-infra.

  ## Benefits which Kustomize brings with it

  - No Helm templating - plain Kubernetes YAML
  - GitOps-native (ArgoCD, Flux)
  - Modular components (mix and match features)
  - Easier to understand and debug

  ## Quick Migration

  ### Before (Helm)
  ```bash
  helm install gateway llm-d-infra/llm-d-infra \
    --set gateway.gatewayClassName=istio \
    --set ingress.enabled=true
  ```
  ### After (Kustomize)
  ```bash
  kubectl apply -k kustomize/examples/istio-with-ingress
  ```
  ### Mapping
  ``` bash
  | Helm                                 | Kustomize                           |
  |--------------------------------------|-------------------------------------|
  | Chart                                | overlays/istio or overlays/kgateway |
  | --set gateway.gatewayClassName=istio | overlays/istio/                     |
  | --set ingress.enabled=true           | components: [ingress]               |
  | Custom values file                   | Create custom kustomization.yaml    |
  | helm upgrade                         | kubectl apply -k                    |
  | helm uninstall                       | kubectl delete -k                   |
  ```
  ### Step-by-Step guide

  1. Identify Your Current Helm Values

  `helm get values gateway -o yaml > current-values.yaml`

  2. Find Equivalent Kustomize Configuration

  Check examples/ for matching configuration.

  3. Customize if Needed

  Create your own kustomization:
  ``` bash
  # my-deployment/kustomization.yaml
  resources:
    - github.com/llm-d-incubation/llm-d-infra//kustomize/overlays/istio

  namespace: my-namespace
  namePrefix: my-

  patches:
    # Your customizations here
  ```
  4. Deploy
  
  ``` bash 
  kubectl apply -k my-deployment/
  ```
  
  ### Common Scenarios

  #### Scenario: Custom Resource Limits

  ##### Helm:
  ``` bash
  gateway:
    gatewayParameters:
      resources:
        limits:
          cpu: "4"
          memory: 2Gi
  ```
  ##### Kustomize:
  Use examples/istio-with-ingress as template (has production resources).

  #### Scenario: Multiple Environments

  ##### Helm:
  ``` bash
  helm install dev-gateway ... -f dev-values.yaml
  helm install prod-gateway ... -f prod-values.yaml
  ```
  
  ##### Kustomize:
  ``` bash
  deployments/
  ├── dev/
  │   └── kustomization.yaml  # references overlays/istio
  └── prod/
      └── kustomization.yaml  # references examples/istio-with-tls
  ```
  
  #### Scenario: GitOps (ArgoCD)

  ##### Helm:
  ``` bash
  source:
    chart: llm-d-infra
    repoURL: https://llm-d-incubation.github.io/llm-d-infra/
    helm:
      values: |
        gateway:
          gatewayClassName: istio
  ```
  
  ##### Kustomize:
  ``` bash
  source:
    repoURL: https://github.com/llm-d-incubation/llm-d-infra
    path: kustomize/overlays/istio
  ```
  ### Rollback Plan

  Keep Helm deployed during migration:

  1. Deploy kustomize to different namespace
  2. Test thoroughly
  3. Switch traffic
  4. Remove Helm deployment

  Need Help?

  - See README.md for full documentation
  - Check examples/ for common patterns
  - Ask in #sig-installation Slack channel