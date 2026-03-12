
# `llm-d-infra`

This repository provides the Kubernetes infrastructure components, Helm charts, and operational tooling for deploying [llm-d](https://github.com/llm-d/llm-d) - a Kubernetes-native high-performance distributed LLM inference framework.

## What This Repository Contains

**Infrastructure Components:**

- Helm charts for deploying llm-d gateway infrastructure
- Kubernetes Gateway API configurations with support for Istio, Kgateway
  (both Envoy and [agentgateway](https://agentgateway.dev/) data planes), and GKE
- Service mesh integration and traffic management policies

**Operational Tooling:**

- Interactive benchmarking and testing utilities
- Smoke testing scripts for deployment validation
- Development helpers and automation tools

## Quick Start

### Prerequisites

- Kubernetes 1.28+ cluster
- Helm 3.10+
- Gateway API v1.4.0+ installed
- Gateway controller (Istio, Kgateway, AgentGateway or GKE) deployed in your cluster

### Install llm-d Infrastructure with Helm

```bash
# Add the Helm repository
helm repo add llm-d-infra https://llm-d-incubation.github.io/llm-d-infra/
helm repo update

# Install the infrastructure components
helm install my-llm-d-infra llm-d-infra/llm-d-infra
```

For detailed configuration options, see the [Helm chart documentation](charts/llm-d-infra/README.md).

## Installation llm-d Infrastructure with Kustomize

For kustomize-based deployments, see [kustomize/README.md](kustomize/README.md).

### Quick Start

```bash
# Istio gateway
kubectl apply -k https://github.com/llm-d-incubation/llm-d-infra//kustomize/overlays/istio

# Kgateway
kubectl apply -k https://github.com/llm-d-incubation/llm-d-infra//kustomize/overlays/kgateway

# GKE
kubectl apply -k https://github.com/llm-d-incubation/llm-d-infra//kustomize/overlays/gke

See kustomize/ for examples and customization guide.

## Documentation and Guides

**Note:** All quickstart guides and user documentation have moved to the main llm-d repository:

- [**Deployment Guides:**](https://github.com/llm-d/llm-d/tree/main/guides)

**This repository contains:**

- [Helm Chart Documentation](charts/llm-d-infra/README.md)
- [Development Guide](docs/development.md)

## Contributing

1. **Issues and Features:** Report issues or request features in the [main llm-d repository](https://github.com/llm-d/llm-d/issues)
2. **Infrastructure Changes:** Submit pull requests to this repository for:
   - Helm chart improvements
   - Operational tooling enhancements
   - Infrastructure configuration updates
3. **Development Setup:** See [development documentation](docs/development.md)

### Code Owners

See [CODEOWNERS](CODEOWNERS) for component-specific maintainers.

## Releases

- **Helm Charts:** Available via the Helm repository: `helm repo add llm-d-infra https://llm-d-incubation.github.io/llm-d-infra/`

- **Release Notes:** [GitHub releases](https://github.com/llm-d-incubation/llm-d-infra/releases)

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
