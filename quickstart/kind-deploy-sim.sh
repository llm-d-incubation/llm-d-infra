#!/bin/bash

# This script automates the setup of the llm-d-infra simulation in kind.
# It handles cluster creation, dependency installation, and deployment.
# It supports both kgateway (default) and istio gateways.

set -euo pipefail

# --- Configuration Variables ---
GATEWAY="kgateway"
CLUSTER_NAME="llm-d-sim"
NAMESPACE="llm-d"
RELEASE_NAME="infra-sim"
METRICS_FLAG=""

# --- Functions ---

# Function to display usage information
usage() {
    echo "Usage: $0 [--gateway <kgateway|istio>] [--skip-metrics] [--help]"
    echo ""
    echo "Options:"
    echo "  --gateway <name>  Specify the gateway. Options: 'kgateway', 'istio'. Default: 'kgateway'."
    echo "  --skip-metrics        Disable metrics collection in the llmd-infra-installer."
    echo "  --help            Display this help message and exit."
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gateway)
            GATEWAY="$2"
            shift 2
            ;;
        --skip-metrics)
            METRICS_FLAG="--disable-metrics-collection"
            shift 1
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
done

# Validate gateway choice
if [[ "$GATEWAY" != "kgateway" && "$GATEWAY" != "istio" ]]; then
    echo "Error: Invalid gateway '$GATEWAY'. Please choose 'kgateway' or 'istio'."
    exit 1
fi

# --- Main Script ---

echo "🚀 Starting LLM-d Simulation Setup..."
echo "----------------------------------------"
echo "Cluster Name: $CLUSTER_NAME"
echo "Namespace:    $NAMESPACE"
echo "Gateway:      $GATEWAY"
echo "----------------------------------------"

echo -e "\n[STEP 1/5] Creating kind cluster '$CLUSTER_NAME'..."
kind create cluster --name "$CLUSTER_NAME"

echo -e "\n[STEP 2/5] Installing dependencies..."
# This command is run from the 'quickstart' directory
./install-deps.sh

echo -e "\n[STEP 3/5] Preparing namespace and base infrastructure..."
# This command is also run from the 'quickstart' directory
# The $METRICS_FLAG variable will be empty unless --skip-metrics is used
HF_TOKEN=dummy ./llmd-infra-installer.sh --namespace "$NAMESPACE" --gateway "$GATEWAY" --release "$RELEASE_NAME" $METRICS_FLAG

echo -e "\n[STEP 4/5] Deploying simulation workloads..."
# Navigate from 'quickstart' to 'examples/sim'
pushd examples/sim
helmfile --selector managedBy=helmfile apply
popd

# Apply Istio fix if istio gateway is selected
if [ "$GATEWAY" == "istio" ]; then
    echo -e "\nApplying Istio DestinationRule fix..."
    export EPP_NAMESPACE="$NAMESPACE"

    # Find the EPP service name now that all workloads are deployed.
    EPP_NAME=$(kubectl get svc -n "${EPP_NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -- "-epp" | head -n1 || true)

    if [ -z "$EPP_NAME" ]; then
        echo "Error: Could not find the EPP service name. Cannot apply Istio fix."
        echo "Run 'kubectl get svc -n ${EPP_NAMESPACE}' to debug."
        exit 1
    fi

    echo "Found EPP service: $EPP_NAME. Applying DestinationRule..."
    cat <<EOF | kubectl apply -n "${EPP_NAMESPACE}" -f -
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ${EPP_NAME}-insecure-tls
spec:
  host: ${EPP_NAME}
  trafficPolicy:
    tls:
      mode: SIMPLE
      insecureSkipVerify: true
EOF
    echo "Istio DestinationRule applied."
fi

echo -e "\n[STEP 5/5] Waiting up to 5 minutes for all pods in '$NAMESPACE' to be ready..."
kubectl wait --for=condition=ready pod -n "$NAMESPACE" --all --timeout=300s
echo "All pods are ready."

echo -e "\n✅ Setup complete!"
echo -e "\n(optional) Set your context with: kubectl config set-context --current --namespace=llm-d"
echo -e "\n🧹 To clean up the environment, run: kind delete cluster --name $CLUSTER_NAME"
