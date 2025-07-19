#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
#   Simple IGW smoke-test:
#     1) GET /v1/models
#     2) POST /v1/completions
#
#   Exits 1 if any call fails (non-zero exit) or returns no JSON.
# -----------------------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --namespace NAMESPACE   Kube namespace to use (default: llm-d)
  -m, --model MODEL_ID        Model to query (env MODEL_ID if unset)
  -h, --help                  Show this help message and exit
EOF
  exit 0
}

NAMESPACE="llm-d"
CLI_MODEL_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace)
      NAMESPACE="$2"; shift 2 ;;
    -m|--model)
      CLI_MODEL_ID="$2"; shift 2 ;;
    -h|--help)
      show_help ;;
    *)
      echo "Unknown option: $1" >&2
      show_help ;;
  esac
done

# ── Determine MODEL_ID ───────────────────────────────────────────────────────
if [[ -n "$CLI_MODEL_ID" ]]; then
  MODEL_ID="$CLI_MODEL_ID"
elif [[ -n "${MODEL_ID-}" ]]; then
  MODEL_ID="$MODEL_ID"
else
  echo "Error: MODEL_ID not set (use -m or export MODEL_ID)" >&2
  exit 1
fi

echo "Namespace: $NAMESPACE"
echo "Model ID:  $MODEL_ID"
echo

# ── Generate unique pod suffix  ─────────────────────────────────────────────
gen_id() { echo $(( RANDOM % 10000 + 1 )); }

# ── Minikube gateway host:port ──────────────────────────────────────────────
SVC_HOST="llm-d-inference-gateway.${NAMESPACE}.svc.cluster.local:80"

# ── Main loop: (n) iterations of GET and POST ────────────────────────────────
for i in {1..10}; do
  echo "=== Iteration $i of 10 ==="
  failed=false

  # — 1) GET /v1/models via DNS gateway —
  echo "1) GET /v1/models at ${SVC_HOST}"
  ret=0
  output=$(kubectl run --rm -i curl-$(gen_id) \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS -X GET "http://${SVC_HOST}/v1/models" \
         -H 'accept: application/json' \
         -H 'Content-Type: application/json') || ret=$?
  echo "$output"
  # detect non-zero exit OR missing JSON (“{”)
  if [[ $ret -ne 0 || "$output" != *'{'* ]]; then
    echo "Error: GET /v1/models failed (exit $ret or no JSON response)" >&2
    failed=true
  fi
  echo

  # — 2) POST /v1/completions via IGW —
  echo "2) POST /v1/completions at ${SVC_HOST}"
  payload='{"model":"'"$MODEL_ID"'","prompt":"You are a helpful AI assistant."}'
  ret=0
  output=$(kubectl run --rm -i curl-$(gen_id) \
    --namespace "$NAMESPACE" \
    --image=curlimages/curl --restart=Never -- \
    curl -sS -X POST "http://${SVC_HOST}/v1/completions" \
         -H 'accept: application/json' \
         -H 'Content-Type: application/json' \
         -d "$payload") || ret=$?
  echo "$output"
  # detect non-zero exit OR missing JSON
  if [[ $ret -ne 0 || "$output" != *'{'* ]]; then
    echo "Error: POST /v1/completions failed (exit $ret or no JSON response)" >&2
    failed=true
  fi
  echo

  if [[ "$failed" == true ]]; then
    echo "Iteration $i encountered errors; exiting after completing both calls." >&2
    exit 1
  fi
done

echo "✅ All 10 iterations succeeded."
