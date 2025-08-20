#!/usr/bin/env bash
# -*- indent-tabs-mode: nil; tab-width: 4; sh-indentation: 4; -*-

set -euo pipefail

### GLOBALS ###
NAMESPACE="llm-d"
ACTION="install"
SCRIPT_DIR=""
REPO_ROOT=""
INSTALL_DIR=""
CHART_DIR=""
VALUES_FILE="values.yaml"
DEBUG=""
KUBERNETES_CONTEXT=""
SKIP_GATEWAY_PROVIDER=false
ONLY_GATEWAY_PROVIDER=false
GATEWAY_TYPE="istio"
HELM_RELEASE_NAME="llm-d-infra"

# Minikube-specific flags & globals
USE_MINIKUBE=false
HOSTPATH_DIR=${HOSTPATH_DIR:="/mnt/data/llm-d-model-storage"}
REDIS_PV_NAME="redis-hostpath-pv"
REDIS_PVC_NAME="redis-data-redis-master"

### HELP & LOGGING ###
print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --namespace NAME              K8s namespace (default: llm-d)
  -f, --values-file PATH            Path to Helm values.yaml file (default: values.yaml)
  -u, --uninstall                   Uninstall the llm-d components from the current cluster
  -d, --debug                       Add debug mode to the helm install
  -i, --skip-gateway-provider       Skip installing CRDs and the chose gateway control plane, only gateway instance and config
  -e, --only-gateway-provider       Only install CRDs and gateway control plane, skip gateway instance and config
  -k, --minikube                    Deploy on an existing minikube instance with hostPath storage
  -g, --context CONTEXT             Supply a specific Kubernetes context
  -j, --gateway TYPE                Select gateway type (istio, kgateway, gke-l7-regional-external-managed)
  -s, --service-type TYPE           Gateway's service type (LoadBalancer, NodePort)
  -r, --release NAME                (Helm) Chart release name
  -h, --help                        Show this help and exit
EOF
}

# ANSI colour helpers and functions
COLOR_RESET=$'\e[0m'
COLOR_GREEN=$'\e[32m'
COLOR_YELLOW=$'\e[33m'
COLOR_RED=$'\e[31m'
COLOR_BLUE=$'\e[34m'

log_info() {
  echo "${COLOR_BLUE}ℹ️  $*${COLOR_RESET}"
}

log_success() {
  echo "${COLOR_GREEN}✅ $*${COLOR_RESET}"
}

log_error() {
  echo "${COLOR_RED}❌ $*${COLOR_RESET}" >&2
}

die()         { log_error "$*"; exit 1; }

### UTILITIES ###
check_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

check_dependencies() {
  # Verify mikefarah yq is installed
  if ! command -v yq &>/dev/null; then
    die "Required command not found: yq. Please install mikefarah yq from https://github.com/mikefarah/yq?tab=readme-ov-file#install"
  fi
  if ! yq --version 2>&1 | grep -q 'mikefarah'; then
    die "Detected yq is not mikefarah’s yq. Please install the required yq from https://github.com/mikefarah/yq?tab=readme-ov-file#install"
  fi

  local required_cmds=(git yq jq helm helmfile kubectl kustomize)
  for cmd in "${required_cmds[@]}"; do
    check_cmd "$cmd"
  done
}

check_cluster_reachability() {
  if kubectl cluster-info &> /dev/null; then
    log_info "kubectl can reach to a running Kubernetes cluster."
  else
    die "kubectl cannot reach any running Kubernetes cluster. The installer requires a running cluster"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--namespace)                  NAMESPACE="$2"; shift 2 ;;
      -f|--values-file)                VALUES_FILE="$2"; shift 2 ;;
      -u|--uninstall)                  ACTION="uninstall"; shift ;;
      -d|--debug)                      DEBUG="--debug"; shift;;
      -i|--skip-gateway-provider)      SKIP_GATEWAY_PROVIDER=true; shift;;
      -e|--only-gateway-provider)      ONLY_GATEWAY_PROVIDER=true; shift;;
      -k|--minikube)                   USE_MINIKUBE=true; shift ;;
      -g|--context)                    KUBERNETES_CONTEXT="$2"; shift 2 ;;
      -j|--gateway)                    GATEWAY_TYPE="$2"; shift 2 ;;
      -s|--service-type)               SERVICE_TYPE="$2"; shift 2 ;;
      -r|--release)                    HELM_RELEASE_NAME="$2"; shift 2 ;;
      -h|--help)                       print_help; exit 0 ;;
      *)                               die "Unknown option: $1" ;;
    esac
  done
}

# Helper to read a top-level value from override if present,
# otherwise fall back to chart’s values.yaml, and log the source
get_value() {
  local path="$1" src res
  if [[ "${VALUES_FILE}" != "values.yaml" ]] && \
     yq eval "has(${path})" - <"${SCRIPT_DIR}/${VALUES_FILE}" &>/dev/null; then
    src="$(realpath "${SCRIPT_DIR}/${VALUES_FILE}")"
  else
    src="${CHART_DIR}/values.yaml"
  fi
  >&2 log_info "🔹 Reading ${path} from ${src}"
  res=$(yq eval -r "${path}" "${src}")
  log_info "🔹 got ${res}"
  echo "${res}"
}

# Populate VALUES_PATH and VALUES_ARGS for any value overrides
resolve_values() {
  local base="${CHART_DIR}/values.yaml"
  [[ -f "${base}" ]] || die "Base values.yaml not found at ${base}"

  if [[ "${VALUES_FILE}" != "values.yaml" ]]; then
    local ov="${VALUES_FILE}"
    if   [[ -f "${ov}" ]]; then :;
    elif [[ -f "${SCRIPT_DIR}/${ov}" ]]; then ov="${SCRIPT_DIR}/${ov}";
    elif [[ -f "${REPO_ROOT}/${ov}" ]]; then    ov="${REPO_ROOT}/${ov}";
    else die "Override values file not found: ${ov}"; fi
    ov="$(realpath "${ov}")"
    local tmp; tmp=$(mktemp)
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' "${base}" "${ov}" >"${tmp}"
    VALUES_PATH="${tmp}"
    VALUES_ARGS=(--values "${base}" --values "${ov}")
  else
    # no override, only base
    VALUES_PATH="${base}"
    VALUES_ARGS=(--values "${base}")
  fi

  log_info "🔹 Using merged values: ${VALUES_PATH}"
}

### ENV & PATH SETUP ###
setup_env() {
  log_info "📂 Setting up script environment..."
  SCRIPT_DIR=$(realpath "$(pwd)")
  REPO_ROOT=$(git rev-parse --show-toplevel)
  INSTALL_DIR=$(realpath "${REPO_ROOT}/quickstart")
  CHART_DIR=$(realpath "${REPO_ROOT}/charts/llm-d-infra")

  if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    die "Script must be run from ${INSTALL_DIR}"
  fi

  if [[ ! -z $KUBERNETES_CONTEXT ]]; then
    if [[ ! -f $KUBERNETES_CONTEXT ]]; then
      log_error "Error, the context file \"$KUBERNETES_CONTEXT\", passed via command-line option, does not exist!"
      exit 1
    fi
    KCMD="kubectl --kubeconfig $KUBERNETES_CONTEXT"
    HCMD="helm --kubeconfig $KUBERNETES_CONTEXT"

  else
    KCMD="kubectl"
    HCMD="helm"
  fi
}

validate_flags() {
  validate_hf_token
  validate_gateway_flags
}

validate_hf_token() {
  HF_SECRET_ENABLED=$(yq -r .auth.hf_token.enabled "${VALUES_PATH}")
  if [[ "${HF_SECRET_ENABLED}" == "true" ]]; then
    if [[ "$ACTION" == "install" ]]; then
        # HF_TOKEN from the env
        [[ -n "${HF_TOKEN:-}" ]] || die "HF_TOKEN not set; Run: export HF_TOKEN=<your_token>"
        log_success "HF_TOKEN validated"
    fi
    HF_NAME=$(yq -r .auth.hf_token.secretName "${VALUES_PATH}")
    HF_KEY=$(yq -r .auth.hf_token.secretKey  "${VALUES_PATH}")
    [[ -n "${HF_NAME:-}" ]] || die "\`.auth.hf_token.secretName not set - set this in your values file: ${VALUES_PATH}"
    [[ -n "${HF_KEY:-}" ]] || die "\`.auth.hf_token.secretKEY not set - set this in your values file: ${VALUES_PATH}"
  fi
}

validate_gateway_flags() {
  # Define supported gateway types
  local supported_gateway_types=("istio" "kgateway" "gke-l7-regional-external-managed")

  # Define supported service types
  local supported_service_types=("LoadBalancer" "NodePort")

  # Validate gateway type
  local gateway_valid=false
  for type in "${supported_gateway_types[@]}"; do
    if [[ "${GATEWAY_TYPE}" == "${type}" ]]; then
      gateway_valid=true
      break
    fi
  done

  if [[ "${gateway_valid}" == "false" ]]; then
    local gateway_types_str=$(IFS=', '; echo "${supported_gateway_types[*]}")
    die "Invalid gateway type: ${GATEWAY_TYPE}. Supported types are: ${gateway_types_str}."
  fi
  log_success "Gateway type validated: ${GATEWAY_TYPE}"

  # Validate service type
  if [[ -n "${SERVICE_TYPE:-}" ]]; then
    local service_valid=false
    for type in "${supported_service_types[@]}"; do
      if [[ "${SERVICE_TYPE}" == "${type}" ]]; then
        service_valid=true
        break
      fi
    done

    if [[ "${service_valid}" == "false" ]]; then
      local service_types_str=$(IFS=', '; echo "${supported_service_types[*]}")
      die "Invalid service type: ${SERVICE_TYPE}. Supported types are: ${service_types_str}."
    fi
    log_success "Gateway Service type validated: ${SERVICE_TYPE}"
  else
    log_info "Gateway Service type not specified, using default: NodePort"
  fi
}

install() {
  if [[ "${SKIP_GATEWAY_PROVIDER}" == "false" ]]; then
    log_info "🏗️ Installing GAIE Kubernetes infrastructure…"
    bash ../chart-dependencies/ci-deps.sh apply ${GATEWAY_TYPE}
    log_success "GAIE infra applied"
  fi

  if [[ "${ONLY_GATEWAY_PROVIDER}" == "true" ]]; then
    log_info "Option \"-e/--only-gateway-provider\" specified, will end execution"
    return 0
  fi


  log_info "📦 Creating namespace ${NAMESPACE}..."
  $KCMD create namespace "${NAMESPACE}" --dry-run=client -o yaml | $KCMD apply -f -
  log_success "Namespace ready"

  cd "${CHART_DIR}"


  if [[ "${HF_SECRET_ENABLED}" == "true" ]]; then
    log_info "🔐 Creating/updating HF token secret..."
    $KCMD delete secret "${HF_NAME}" -n "${NAMESPACE}" --ignore-not-found
    $KCMD create secret generic "${HF_NAME}" \
        --namespace "${NAMESPACE}" \
        --from-literal="${HF_KEY}=${HF_TOKEN}" \
        --dry-run=client -o yaml | $KCMD apply -n "${NAMESPACE}" -f -
    log_success "HF token secret \`${HF_NAME}\` created with secret stored in key \`${HF_KEY}\`"
  fi

  $HCMD repo add bitnami  https://charts.bitnami.com/bitnami
  log_info "🛠️ Building Helm chart dependencies..."
  $HCMD dependency build .
  log_success "Dependencies built"

  if is_openshift; then
    BASE_OCP_DOMAIN=$($KCMD get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.domain}')
    OCP_DISABLE_INGRESS_ARGS=(
      --set ingress.enabled=false
    )
  else
    BASE_OCP_DOMAIN=""
    OCP_DISABLE_INGRESS_ARGS=()
  fi


  log_info "🚚 Deploying llm-d-infra chart with ${VALUES_PATH}..."
  $HCMD upgrade -i ${HELM_RELEASE_NAME} . \
    ${DEBUG} \
    --namespace "${NAMESPACE}" \
    "${VALUES_ARGS[@]}" \
    "${OCP_DISABLE_INGRESS_ARGS[@]+"${OCP_DISABLE_INGRESS_ARGS[@]}"}" \
    --set gateway.gatewayClassName="${GATEWAY_TYPE}" \
    --set ingress.clusterRouterBase="${BASE_OCP_DOMAIN}" \
    --set gateway.serviceType="${SERVICE_TYPE:-NodePort}"
  log_success "$HELM_RELEASE_NAME deployed"

  log_success "🎉 Installation complete."
}

uninstall() {
  if [[ "${SKIP_GATEWAY_PROVIDER}" == "false" ]]; then
    log_info "🗑️ Tearing down GAIE Kubernetes infrastructure…"
    bash ../chart-dependencies/ci-deps.sh delete ${GATEWAY_TYPE}
  fi

  log_info "🗑️ Uninstalling llm-d chart..."
  $HCMD uninstall ${HELM_RELEASE_NAME} --ignore-not-found --namespace "${NAMESPACE}" || true

  log_info "🗑️ Deleting namespace ${NAMESPACE}..."
  $KCMD delete namespace "${NAMESPACE}" --ignore-not-found || true


  log_success "💀 Uninstallation complete"
}



is_openshift() {
  # Check for OpenShift-specific resources
  if $KCMD get clusterversion &>/dev/null; then
    return 0
  fi
  return 1
}


main() {
  parse_args "$@"

  setup_env
  check_dependencies

  # Check cluster reachability as a pre-requisite
  check_cluster_reachability
  resolve_values

  validate_flags

  if [[ "$ACTION" == "install" ]]; then
    install
  elif [[ "$ACTION" == "uninstall" ]]; then
    uninstall
  else
    die "Unknown action: $ACTION"
  fi
}

main "$@"
