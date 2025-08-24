# Customizing your Gateway

This document is meant to walk through some choices when setting up your gateway.

## Using an Ingress

If using a gateway service of type `ClusterIP` you have the option to create an ingress to expose your gateway

```yaml
gateway:
  service:
    type: ClusterIP
ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
```

## Gateway Considerations for Benchmarking

### Increasing Envoy Pod Resources

### Increasing Max Connections and Timeout (Istio only)

### Changing log levels
