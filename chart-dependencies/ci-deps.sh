#!/bin/bash
# -*- indent-tabs-mode: nil; tab-width: 2; sh-indentation: 2; -*-

# This is a dependency for the CI job .github/workflows/test.yaml
# Prep installation of dependencies for GAIE

set +x
set -e
set -o pipefail

if [ -z "$(command -v kubectl)" ] || [ -z "$(command -v helm)" ]; then
    echo "This script depends on \`kubectl\` and \`helm\`. Please install them."
    exit 1
fi

# Logging functions and ASCII colour helpers.
COLOR_RESET=$'\e[0m'
COLOR_GREEN=$'\e[32m'
log_success() {
  echo "${COLOR_GREEN}✅ $*${COLOR_RESET}"
}

CWD=$( dirname -- "$( readlink -f -- "$0"; )"; )

## Populate manifests
MODE=${1:-apply} # allowed values "apply" or "delete"
BACKEND=${2:-$(helm show values $CWD/../charts/llm-d-infra --jsonpath '{.gateway.gatewayClassName}')}
if [[ "$MODE" == "apply" ]]; then
    LOG_ACTION_NAME="Installing"
else
    LOG_ACTION_NAME="Deleting"
fi

### Base CRDs
log_success "📜 Base CRDs: ${LOG_ACTION_NAME}..."
kubectl $MODE -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gateway-api || true

### GAIE CRDs
log_success "🚪 GAIE CRDs: ${LOG_ACTION_NAME}..."
kubectl $MODE -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gie || true

### Install Gateway provider
log_success "🎒 Gateway provider '${COLOR_BLUE}${BACKEND}${COLOR_RESET}${COLOR_GREEN}': ${LOG_ACTION_NAME}...${COLOR_RESET}"

$CWD/$BACKEND/install.sh $MODE
