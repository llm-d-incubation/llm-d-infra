#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# test-request.sh
#
# Description:
#   Quick smoke tests against your llm-d deployment:
#     1) GET  /v1/models      on the decode pod
#     2) POST /v1/completions on the decode pod
#     3) GET  /v1/models      via the gateway
#     4) POST /v1/completions via the gateway
# -----------------------------------------------------------------------------

set -euo pipefail

if ! command -v kubectl &>/dev/null; then
  echo "Error: 'kubectl' not found in PATH." >&2
  exit 1
fi

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Quick smoke tests against your llm-d deployment.

Options:
  -n, --namespace NAMESPACE   Kubernetes namespace to use (default: llm-d)
  -m, --model MODEL_ID        Model to query (optional; discovered if omitted)
  -v, --verbose               Display the kubectl run commands being executed
  -h, --help                  Show this help message and exit
EOF
  exit 0
}

NAMESPACE="llm-d"
CLI_MODEL_ID=""
VERBOSE=false
FAILED_COUNT=0

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -m|--model)
      CLI_MODEL_ID="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

MODEL_ID="${CLI_MODEL_ID:-}"

echo "Namespace: $NAMESPACE"
echo "Model ID:  ${MODEL_ID:-none; will be discovered from first entry in /v1/models}"
echo

# ── generate a unique suffix ───────────────────────────────────────
gen_id() { echo $(( RANDOM % 10000 + 1 )); }

# ── Extract all model IDs ──────────────
extract_models() {
  printf '%s' "$1" | grep -o '"id":"[^"]*"' | cut -d'"' -f4
}

# ── Grab the FIRST model ID ───────────────────────────────────
infer_first_model() {
  printf '%s' "$1" | grep -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4
}

print_cmd() {
  echo "  - Running command:"
  echo "    kubectl run --rm -i curl-$1 \\
      --namespace \"$NAMESPACE\" \\
      --image=curlimages/curl --restart=Never -- \\
      curl $2"
}

validation() {
  echo "-> Discovering decode pod…"
  POD_IP=$(kubectl get pods -n "$NAMESPACE" \
    -o jsonpath='{range .items[*]}{.metadata.name} {" "} {.status.podIP}{"\n"}{end}' \
    | grep decode | awk '{print $2}' | head -1)

  if [[ -z "$POD_IP" ]]; then
    echo "❌ Failed: No decode pod found in namespace $NAMESPACE"
    ((FAILED_COUNT++))
    return
  else
    echo "✅ Success: Found decode pod at ${POD_IP}"
  fi
  echo

  echo "1 -> GET /v1/models from decode pod…"
  ID=$(gen_id)
  [[ "$VERBOSE" == true ]] && print_cmd "$ID" "-sS --fail http://${POD_IP}:8000/v1/models -H 'accept: application/json' -H 'Content-Type: application/json'"

  set +e
  LIST_JSON=$(kubectl run --rm -i curl-$ID --namespace "$NAMESPACE" --image=curlimages/curl --restart=Never -- \
    curl -sS --fail http://${POD_IP}:8000/v1/models \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json')
  EXIT_CODE=$?
  set -e

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Success"
    echo "$LIST_JSON"
  else
    echo "❌ Failed (Exit Code: $EXIT_CODE)"
    ((FAILED_COUNT++))
    return
  fi
  echo

  echo "-> Validating model ID…"
  if [[ -z "$MODEL_ID" ]]; then
    MODEL_ID=$(infer_first_model "$LIST_JSON")
    echo "✅ Success: Discovered model to use: $MODEL_ID"
  else
    if ! grep -q "\"id\":\"$MODEL_ID\"" <<<"$LIST_JSON"; then
      echo "❌ Failed: Requested model '$MODEL_ID' not found in available models:"
      extract_models "$LIST_JSON"
      ((FAILED_COUNT++))
    else
      echo "✅ Success: Model '$MODEL_ID' is available."
    fi
  fi
  echo

  echo "2 -> POST /v1/completions to decode pod…"
  ID=$(gen_id)
  [[ "$VERBOSE" == true ]] && print_cmd "$ID" "-sS --fail -X POST http://${POD_IP}:8000/v1/completions -H 'accept: application/json' -H 'Content-Type: application/json' -d '{\"model\":\"$MODEL_ID\",\"prompt\":\"Who are you?\"}'"

  set +e
  COMPLETION_JSON=$(kubectl run --rm -i curl-$ID --namespace "$NAMESPACE" --image=curlimages/curl --restart=Never -- \
    curl -sS --fail -X POST http://${POD_IP}:8000/v1/completions \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{"model":"'"$MODEL_ID"'","prompt":"Who are you?"}')
  EXIT_CODE=$?
  set -e

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Success"
    echo "$COMPLETION_JSON"
  else
    echo "❌ Failed (Exit Code: $EXIT_CODE)"
    ((FAILED_COUNT++))
    echo "$COMPLETION_JSON"
  fi
  echo

  echo "-> Discovering gateway service…"
  GATEWAY_SVC=$(kubectl get svc -n "$NAMESPACE" -o json | jq -r '.items[] | select(.metadata.name | test(".*-inference-gateway(-.*)?$")).metadata.name' | head -n1)

  if [[ -z "$GATEWAY_SVC" ]]; then
    echo "❌ Failed: Could not find a gateway service in namespace $NAMESPACE"
    ((FAILED_COUNT++))
    return
  fi

  GATEWAY_HOST="${GATEWAY_SVC}.${NAMESPACE}.svc.cluster.local"

  echo "✅ Success: Using gateway service $GATEWAY_HOST"
  echo

  echo "3 -> GET /v1/models via gateway…"
  ID=$(gen_id)
  [[ "$VERBOSE" == true ]] && print_cmd "$ID" "-sS --fail http://${GATEWAY_HOST}/v1/models -H 'accept: application/json' -H 'Content-Type: application/json'"

  set +e
  GW_JSON=$(kubectl run --rm -i curl-$ID --namespace "$NAMESPACE" --image=curlimages/curl --restart=Never -- \
    curl -sS --fail http://${GATEWAY_HOST}/v1/models \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json')
  EXIT_CODE=$?
  set -e

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Success"
    echo "$GW_JSON"
  else
    echo "❌ Failed (Exit Code: $EXIT_CODE)"
    ((FAILED_COUNT++))
  fi
  echo

  echo "4 -> POST /v1/completions via gateway…"
  ID=$(gen_id)
  [[ "$VERBOSE" == true ]] && print_cmd "$ID" "-sS --fail -X POST http://${GATEWAY_HOST}/v1/completions -H 'accept: application/json' -H 'Content-Type: application/json' -d '{\"model\":\"$MODEL_ID\",\"prompt\":\"Who are you?\"}'"

  set +e
  GW_COMPLETION_JSON=$(kubectl run --rm -i curl-$ID --namespace "$NAMESPACE" --image=curlimages/curl --restart=Never -- \
    curl -sS --fail -X POST http://${GATEWAY_HOST}/v1/completions \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '{"model":"'"$MODEL_ID"'","prompt":"Who are you?"}')
  EXIT_CODE=$?
  set -e

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Success"
    echo "$GW_COMPLETION_JSON"
  else
    echo "❌ Failed (Exit Code: $EXIT_CODE)"
    ((FAILED_COUNT++))
    echo "$GW_COMPLETION_JSON"
  fi
  echo
}

# ── Main ─────────────────────────────────────────────────────────────────────
validation

echo "────────────────────────────────────────────────────────────────"
if [[ $FAILED_COUNT -gt 0 ]]; then
  echo "${FAILED_COUNT} test(s) failed."
  exit 1
else
  echo "🚀 All tests passed."
fi
