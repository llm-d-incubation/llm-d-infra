#!/usr/bin/env bash

MODE=${1:-apply}
# TAG=1.27-alpha.0551127f00634403cddd4634567e65a8ecc499a7
TAG=1.28-alpha.89f30b26ba71bf5e538083a4720d0bc2d8c06401
HUB=gcr.io/istio-testing

if [[ "$MODE" == "apply" ]]; then
    helm upgrade -i istio-base oci://$HUB/charts/base --version $TAG -n istio-system --create-namespace
    helm upgrade -i istiod oci://$HUB/charts/istiod \
      --version $TAG \
      -n istio-system \
      --set meshConfig.defaultConfig.proxyMetadata.SUPPORT_GATEWAY_API_INFERENCE_EXTENSION="true" \
      --set pilot.env.SUPPORT_GATEWAY_API_INFERENCE_EXTENSION="true" \
      --set tag=$TAG \
      --set hub=$HUB \
      --wait
    # helm upgrade -i istiod oci://$HUB/charts/istiod --version $TAG -n istio-system --set tag=$TAG --set hub=$HUB --wait
else
  helm uninstall istiod --ignore-not-found --namespace istio-system || true
  helm uninstall istio-base --ignore-not-found --namespace istio-system || true
  helm template istio-base oci://$HUB/charts/base --version $TAG -n istio-system | kubectl delete -f - --ignore-not-found
fi
