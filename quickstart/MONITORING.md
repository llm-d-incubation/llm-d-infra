# Quickstart Observability & Monitoring Guide

This guide explains how to set up monitoring and observability for llm-d deployments.
The llm-d quickstart provides a Prometheus and Grafana installation script with two deployment patterns:

## Overview

1. **Central Monitoring (Default)**: Single Prometheus instance monitors all namespaces automatically
2. **Individual User Monitoring**: Each user has their own isolated Prometheus/Grafana stack

## Quick Start

### Step 1: Install Monitoring Stack

```bash
# Central monitoring (default - monitors all namespaces)
./install-prometheus-grafana.sh

# Individual user monitoring (isolated)
./install-prometheus-grafana.sh --individual
```

### Step 2: Enable Monitoring for Your Deployments

Choose the approach that matches your monitoring setup:

#### Option A: Central Monitoring (Default)

**No additional configuration required!** Central monitoring automatically discovers all ServiceMonitors and PodMonitors across all namespaces.

#### Option B: Individual User Monitoring

```bash
# Label your namespace for individual monitoring
kubectl label namespace <your-namespace> monitoring-user=$USER
```

### Step 3: Enable Metrics in Your Deployments

Update your modelservice values to enable monitoring:

```yaml
# In your ms-*/values.yaml files
routing:
  epp:
    monitoring:
      servicemonitor:
        enabled: true

decode:
  monitoring:
    podmonitor:
      enabled: true

prefill:
  monitoring:
    podmonitor:
      enabled: true
```

### Step 4: Access Your Dashboards

```bash
# For central monitoring
kubectl port-forward -n llm-d-monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n llm-d-monitoring svc/prometheus-grafana 3000:80

# For individual monitoring
kubectl port-forward -n ${USER}-llm-d-monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n ${USER}-llm-d-monitoring svc/prometheus-grafana 3000:80

# Grafana login: admin/admin
```

## Integration with Helmfile Examples

### Central Monitoring (Recommended)

Since central monitoring watches all namespaces automatically, no additional configuration is needed in your helmfiles. Simply enable monitoring in your values files:

```yaml
# In your ms-*/values.yaml
routing:
  epp:
    monitoring:
      servicemonitor:
        enabled: true
```

### Individual Monitoring Integration

Add this hook to your `helmfile.yaml` to automatically label namespaces:

```yaml
# Add to any helmfile.yaml for individual monitoring
hooks:
  - name: enable-monitoring
    events: ["postsync"]
    command: kubectl
    args:
      - label
      - namespace
      - <your-namespace>  # Replace with actual namespace
      - monitoring-user={{ env "USER" }}
      - --overwrite
```

### Manual Namespace Labeling (Individual Mode Only)

If you prefer manual control with individual monitoring:

```bash
# After running helmfile sync
kubectl label namespace llm-d-sim monitoring-user=$USER                     # For sim example
kubectl label namespace llm-d-pd monitoring-user=$USER                      # For pd-disaggregation example
kubectl label namespace llm-d-precise monitoring-user=$USER                 # For precise-prefix-cache-aware example
kubectl label namespace llm-d-wide-ep monitoring-user=$USER                 # For wide-ep-lws example
kubectl label namespace llm-d-inference-scheduling monitoring-user=$USER    # For inference-scheduling example
```

## Security & Multi-Tenant Considerations

### Central Monitoring

- ⚠️ **Single-tenant use only**: All users can see all metrics
- **Permissions**: Cluster-admin required for installation
- **Isolation**: No tenant isolation - suitable for trusted environments
- **Simplicity**: Zero configuration for metric collection

### Individual Monitoring

- ✅ **Multi-tenant safe**: Users only see their own metrics
- **Permissions**: Namespace creation + ServiceAccount management
- **Isolation**: Complete isolation between users
- **Configuration**: Requires namespace labeling

### Debugging Commands

```bash
# Check Prometheus targets (central mode)
kubectl port-forward -n llm-d-monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check Prometheus targets (individual mode)
kubectl port-forward -n ${USER}-llm-d-monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check ServiceMonitor/PodMonitor resources
kubectl get servicemonitor,podmonitor -A

# Check namespace labels (individual mode only)
kubectl get namespaces --show-labels | grep monitoring
```

## Cleanup

```bash
# Remove central monitoring stack
./install-prometheus-grafana.sh --uninstall

# Remove individual monitoring stack
./install-prometheus-grafana.sh --uninstall --individual

# Remove namespace labels (individual mode only)
kubectl label namespace <your-ns> monitoring-user-
```
