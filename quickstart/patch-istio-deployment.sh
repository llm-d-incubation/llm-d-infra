export DEP=infra-wide-ep-inference-gateway-istio
export NS=llm-d-wide-ep

kubectl patch deploy "$DEP" -n "$NS" --type='merge' \
  -p='{"spec":{"template":{"spec":{"tolerations":[{"key":"nvidia.com/gpu","operator":"Exists","effect":"NoSchedule"}]}}}}'
  