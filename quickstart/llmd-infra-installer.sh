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
PROXY_UID=""
VALUES_FILE="values.yaml"
DEBUG=""
KUBERNETES_CONTEXT=""
SKIP_GATEWAY_PROVIDER=false
ONLY_GATEWAY_PROVIDER=false
DISABLE_METRICS=false
MONITORING_NAMESPACE="llm-d-monitoring"
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
  -m, --disable-metrics-collection  Disable metrics collection (Prometheus will not be installed)
  -k, --minikube                    Deploy on an existing minikube instance with hostPath storage
  -g, --context                     Supply a specific Kubernetes context
  -j, --gateway                     Select gateway type (istio or kgateway)
  -r, --release                     (Helm) Chart release name
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

# Derive an OpenShift PROXY_UID; default to 0 if not available
fetch_kgateway_proxy_uid() {
  log_info "Fetching OCP proxy UID..."
  local uid_range
  uid_range=$($KCMD get namespace "${NAMESPACE}" -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' 2>/dev/null || true)
  if [[ -n "$uid_range" ]]; then
    PROXY_UID=$(echo "$uid_range" | awk -F'/' '{print $1 + 1}')
    log_success "Derived PROXY_UID=${PROXY_UID}"
  else
    PROXY_UID=0
    log_info "No OpenShift SCC annotation found; defaulting PROXY_UID=${PROXY_UID}"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -z|--storage-size)               STORAGE_SIZE="$2"; shift 2 ;;
      -c|--storage-class)              STORAGE_CLASS="$2"; shift 2 ;;
      -n|--namespace)                  NAMESPACE="$2"; shift 2 ;;
      -f|--values-file)                VALUES_FILE="$2"; shift 2 ;;
      -u|--uninstall)                  ACTION="uninstall"; shift ;;
      -d|--debug)                      DEBUG="--debug"; shift;;
      -i|--skip-gateway-provider)      SKIP_GATEWAY_PROVIDER=true; shift;;
      -e|--only-gateway-provider)      ONLY_GATEWAY_PROVIDER=true; shift;;
      -m|--disable-metrics-collection) DISABLE_METRICS=true; shift;;
      -k|--minikube)                   USE_MINIKUBE=true; shift ;;
      -g|--context)                    KUBERNETES_CONTEXT="$2"; shift 2 ;;
      -j|--gateway)                    GATEWAY_TYPE="$2"; shift 2 ;;
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

validate_gateway_type() {
  if [[ "${GATEWAY_TYPE}" != "istio" && "${GATEWAY_TYPE}" != "kgateway" && "${GATEWAY_TYPE}" != "gke-l7-regional-external-managed" ]]; then
    die "Invalid gateway type: ${GATEWAY_TYPE}. Supported types are: istio, kgateway, gke-l7-regional-external-managed."
  fi
  log_success "Gateway type validated"
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

  if $KCMD get namespace "${MONITORING_NAMESPACE}" &>/dev/null; then
    log_info "🧹 Cleaning up existing monitoring namespace..."
    $KCMD delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found
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

  # can be fetched non-invasily if using kgateway or not
  fetch_kgateway_proxy_uid

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

  local metrics_enabled="true"
  if [[ "${DISABLE_METRICS}" == "true" ]]; then
    log_info "Metrics collection disabled by user request."
    metrics_enabled="false"
  else
    if is_openshift; then
      log_info "Using OpenShift's built-in monitoring stack."
      if ! check_openshift_monitoring; then
        log_info "⚠️ Metrics collection may not work properly in OpenShift without user workload monitoring enabled."
      fi
      # No Prometheus installation needed; metrics_enabled remains true for chart.
    elif [[ "${USE_MINIKUBE}" == "true" ]]; then
      log_info "🌱 Minikube detected; provisioning Prometheus/Grafana…"
      install_prometheus_grafana
    elif ! check_servicemonitor_crd; then
      log_info "⚠️ ServiceMonitor CRD (monitoring.coreos.com) not found. Installing Prometheus stack."
      install_prometheus_grafana
    else
      log_info "ServiceMonitor CRD found. Verifying Prometheus installation..."
      install_prometheus_grafana
    fi
    log_info "Metrics collection enabled"
  fi

  log_info "🚚 Deploying llm-d-infra chart with ${VALUES_PATH}..."
  $HCMD upgrade -i ${HELM_RELEASE_NAME} . \
    ${DEBUG} \
    --namespace "${NAMESPACE}" \
    "${VALUES_ARGS[@]}" \
    "${OCP_DISABLE_INGRESS_ARGS[@]+"${OCP_DISABLE_INGRESS_ARGS[@]}"}" \
    --set gateway.gatewayClassName="${GATEWAY_TYPE}" \
    --set gateway.gatewayParameters.proxyUID="${PROXY_UID}" \
    --set ingress.clusterRouterBase="${BASE_OCP_DOMAIN}" \
    "${MODEL_OVERRIDE_ARGS[@]+"${MODEL_OVERRIDE_ARGS[@]}"}"
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

  log_info "🗑️ Deleting monitoring namespace..."
  $KCMD delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found || true

  # Check if we installed the Prometheus stack and delete the ServiceMonitor CRD if we did
  if $HCMD list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus" 2>/dev/null; then
    log_info "🗑️ Deleting ServiceMonitor CRD..."
    $KCMD delete crd servicemonitors.monitoring.coreos.com --ignore-not-found || true
  fi

  log_success "💀 Uninstallation complete"
}

check_servicemonitor_crd() {
  log_info "🔍 Checking for ServiceMonitor CRD (monitoring.coreos.com)..."
  if ! $KCMD get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
    log_info "⚠️ ServiceMonitor CRD (monitoring.coreos.com) not found"
    return 1
  fi

  API_VERSION=$($KCMD get crd servicemonitors.monitoring.coreos.com -o jsonpath='{.spec.versions[?(@.served)].name}' 2>/dev/null || echo "")

  if [[ -z "$API_VERSION" ]]; then
    log_info "⚠️ Could not determine ServiceMonitor CRD API version"
    return 1
  fi

  if [[ "$API_VERSION" == "v1" ]]; then
    log_success "ServiceMonitor CRD (monitoring.coreos.com/v1) found"
    return 0
  else
    log_info "⚠️ Found ServiceMonitor CRD but with unexpected API version: ${API_VERSION}"
    return 1
  fi
}

check_openshift_monitoring() {
  if ! is_openshift; then
    return 0
  fi

  log_info "🔍 Checking OpenShift user workload monitoring configuration..."

  # Check if user workload monitoring is enabled
  if $KCMD get configmap cluster-monitoring-config -n openshift-monitoring -o yaml 2>/dev/null | grep -q "enableUserWorkload: true"; then
    log_success "✅ OpenShift user workload monitoring is properly configured"
    return 0
  fi

  log_info "⚠️ OpenShift user workload monitoring is not enabled"
  log_info "ℹ️ Enabling user workload monitoring allows metrics collection for the llm-d chart."

  local monitoring_yaml=$(cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF
)

  # Prompt the user
  log_info "📜 The following ConfigMap will be applied to enable user workload monitoring:"
  echo "$monitoring_yaml"
  read -p "Would you like to apply this ConfigMap to enable user workload monitoring? (y/N): " response
  case "$response" in
    [yY][eE][sS]|[yY])
      log_info "🚀 Applying ConfigMap to enable user workload monitoring..."
      echo "$monitoring_yaml" | oc create -f -
      if [[ $? -eq 0 ]]; then
        log_success "✅ OpenShift user workload monitoring enabled"
        return 0
      else
        log_error "❌ Failed to apply ConfigMap. Metrics collection may not work."
        return 1
      fi
      ;;
    *)
      log_info "⚠️ User chose not to enable user workload monitoring."
      log_info "⚠️ Metrics collection may not work properly in OpenShift without user workload monitoring enabled."
      return 1
      ;;
  esac
}

is_openshift() {
  # Check for OpenShift-specific resources
  if $KCMD get clusterversion &>/dev/null; then
    return 0
  fi
  return 1
}

install_prometheus_grafana() {
  log_info "🌱 Provisioning Prometheus operator…"

  if ! $KCMD get namespace "${MONITORING_NAMESPACE}" &>/dev/null; then
    log_info "📦 Creating monitoring namespace..."
    $KCMD create namespace "${MONITORING_NAMESPACE}"
  else
    log_info "📦 Monitoring namespace already exists"
  fi

  if ! $HCMD repo list 2>/dev/null | grep -q "prometheus-community"; then
    log_info "📚 Adding prometheus-community helm repo..."
    $HCMD repo add prometheus-community https://prometheus-community.github.io/helm-charts
    $HCMD repo update
  fi

  if $HCMD list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus"; then
    log_info "⚠️ Prometheus stack already installed in ${MONITORING_NAMESPACE} namespace"
    return 0
  fi

  log_info "🚀 Installing Prometheus stack..."
  # Install minimal Prometheus stack with only essential configurations:
  # - Basic ClusterIP services for Prometheus and Grafana
  # - ServiceMonitor discovery enabled across namespaces
  # - Default admin password for Grafana
  # Note: Ingress and other advanced configurations are left to the user to customize
  cat <<EOF > /tmp/prometheus-values.yaml
grafana:
  adminPassword: admin
  service:
    type: ClusterIP
prometheus:
  service:
    type: ClusterIP
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    podMonitorSelectorNilUsesHelmValues: false
    podMonitorSelector: {}
    podMonitorNamespaceSelector: {}
    maximumStartupDurationSeconds: 300
EOF

  $HCMD install prometheus prometheus-community/kube-prometheus-stack \
    --namespace "${MONITORING_NAMESPACE}" \
    -f /tmp/prometheus-values.yaml \
    1>/dev/null

  rm -f /tmp/prometheus-values.yaml

  log_info "⏳ Waiting for Prometheus stack pods to be ready..."
  $KCMD wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n "${MONITORING_NAMESPACE}" --timeout=300s || true
  $KCMD wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n "${MONITORING_NAMESPACE}" --timeout=300s || true

  log_success "🚀 Prometheus and Grafana installed."
}

main() {
  parse_args "$@"

  setup_env
  check_dependencies

  # Check cluster reachability as a pre-requisite
  check_cluster_reachability
  resolve_values

  validate_hf_token
  validate_gateway_type

  if [[ "$ACTION" == "install" ]]; then
    install
  elif [[ "$ACTION" == "uninstall" ]]; then
    uninstall
  else
    die "Unknown action: $ACTION"
  fi
}

main "$@"
