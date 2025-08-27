export DEP=infra-wide-ep-pd-inference-gateway-istio
export NS=llm-d-wide-ep-pd

kubectl patch deploy "$DEP" -n "$NS" --type='merge' \
  -p='{"spec":{"template":{"spec":{"tolerations":[{"key":"nvidia.com/gpu","operator":"Exists","effect":"NoSchedule"}]}}}}'
