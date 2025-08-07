#!/usr/bin/env bash

MODE=${1:-apply}

# The version of Kgateway to install. Use "v2.1.0-main" for the latest
# build from the Kgateway main branch.
KGTW_VERSION=${KGTW_VERSION:-"v2.0.4"}

if [[ "$MODE" == "apply" ]]; then
  helm upgrade -i \
    --namespace kgateway-system \
    --create-namespace \
    --version "${KGTW_VERSION}" \
    kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds

  helm upgrade -i \
    --namespace kgateway-system \
    --create-namespace \
    --version "${KGTW_VERSION}" \
    --set inferenceExtension.enabled=true \
    --set securityContext.allowPrivilegeEscalation=false \
    --set securityContext.capabilities.drop={ALL} \
    --set podSecurityContext.seccompProfile.type=RuntimeDefault \
    --set podSecurityContext.runAsNonRoot=true \
    kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway
else
  helm uninstall kgateway --ignore-not-found  --namespace kgateway-system || true
  helm uninstall kgateway-crds --ignore-not-found --namespace kgateway-system || true
  helm template kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds --version "${KGTW_VERSION}" | kubectl delete -f - --ignore-not-found
fi
