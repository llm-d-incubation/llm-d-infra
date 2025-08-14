#!/usr/bin/env bash
# -*- indent-tabs-mode: nil; tab-width: 4; sh-indentation: 4; -*-

set -euo pipefail

### GLOBALS ###
# Use central monitoring namespace by default (configurable via MONITORING_NAMESPACE env var)
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-llm-d-monitoring}"
ACTION="install"
KUBERNETES_CONTEXT=""
DEBUG=""
CENTRAL_MODE=true

### HELP & LOGGING ###
print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install or uninstall Prometheus and Grafana stack for llm-d metrics collection.

Options:
  -n, --namespace NAME        Monitoring namespace (default: llm-d-monitoring)
  -u, --uninstall             Uninstall Prometheus and Grafana stack
  -d, --debug                 Add debug mode to the helm install
  -g, --context               Supply a specific Kubernetes context
  -i, --individual            Enable individual user monitoring mode
  -h, --help                  Show this help and exit

Environment Variables:
  MONITORING_NAMESPACE        Override default monitoring namespace (default: llm-d-monitoring)

Examples:
  $(basename "$0")                              # Install central monitoring (watches all namespaces)
  $(basename "$0") -u                           # Uninstall Prometheus/Grafana stack
  $(basename "$0") -i                           # Install individual monitoring in ${USER}-llm-d-monitoring
  $(basename "$0") -n my-monitoring             # Install in custom namespace
  MONITORING_NAMESPACE=custom-monitoring $(basename "$0")  # Use custom namespace via env var
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

die() { log_error "$*"; exit 1; }

### UTILITIES ###
check_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

check_dependencies() {
  local required_cmds=(helm kubectl)
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
      -n|--namespace)                  MONITORING_NAMESPACE="$2"; shift 2 ;;
      -u|--uninstall)                  ACTION="uninstall"; shift ;;
      -d|--debug)                      DEBUG="--debug"; shift;;
      -g|--context)                    KUBERNETES_CONTEXT="$2"; shift 2 ;;
      -i|--individual)                 CENTRAL_MODE=false; shift ;;
      -h|--help)                       print_help; exit 0 ;;
      *)                               die "Unknown option: $1" ;;
    esac
  done
}

setup_env() {
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

  # Set up monitoring labels based on mode
  if [[ "$CENTRAL_MODE" == "true" ]]; then
    MONITORING_NAMESPACE="llm-d-monitoring"
    MONITORING_LABEL_KEY=""
    MONITORING_LABEL_VALUE=""
  else
    MONITORING_NAMESPACE="${USER}-llm-d-monitoring"
    MONITORING_LABEL_KEY="monitoring-user"
    MONITORING_LABEL_VALUE="${USER}"
  fi
}

is_openshift() {
  # Check for OpenShift-specific resources
  if $KCMD get clusterversion &>/dev/null; then
    return 0
  fi
  return 1
}

check_servicemonitor_crd() {
  log_info "🔍 Checking for ServiceMonitor CRD (monitoring.coreos.com)..."
  if ! $KCMD get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
    log_info "⚠️ ServiceMonitor CRD (monitoring.coreos.com) not found - will be installed with Prometheus stack"
    return 1
  fi

  API_VERSION=$($KCMD get crd servicemonitors.monitoring.coreos.com -o jsonpath='{.spec.versions[?(@.served)].name}' 2>/dev/null || echo "")

  if [[ -z "$API_VERSION" ]]; then
    log_info "⚠️ Could not determine ServiceMonitor CRD API version"
    return 1
  fi

  if [[ "$API_VERSION" == "v1" ]]; then
    log_success "ServiceMonitor CRD (monitoring.coreos.com/v1) found - using existing installation"
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
    if [[ "$CENTRAL_MODE" == "true" ]]; then
      log_info "ℹ️ To update existing installation to central mode, first uninstall with: $0 -u -n ${MONITORING_NAMESPACE}"
    else
      log_info "ℹ️ To update configuration, first uninstall with: $0 -u -n ${MONITORING_NAMESPACE}"
    fi
    return 0
  fi

  # Check if CRDs already exist (installed by another user)
  if check_servicemonitor_crd; then
    log_info "🔄 ServiceMonitor CRDs already exist - installing without CRDs to avoid conflicts"
    CRD_INSTALL_FLAG="--skip-crds"
  else
    log_info "🆕 Installing Prometheus stack with CRDs"
    CRD_INSTALL_FLAG=""
  fi

  log_info "🚀 Installing Prometheus stack in namespace ${MONITORING_NAMESPACE}..."

  if [[ "$CENTRAL_MODE" == "true" ]]; then
    # Central mode: Monitor all namespaces without label restrictions
    cat <<EOF > /tmp/prometheus-values.yaml
grafana:
  adminPassword: admin
  service:
    type: ClusterIP
prometheus:
  service:
    type: ClusterIP
  prometheusSpec:
    # Central monitoring: watch all ServiceMonitors and PodMonitors in all namespaces
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    podMonitorSelectorNilUsesHelmValues: false
    podMonitorSelector: {}
    podMonitorNamespaceSelector: {}
    maximumStartupDurationSeconds: 300
    # Higher resource limits for central monitoring
    resources:
      limits:
        memory: 8Gi
        cpu: 4000m
      requests:
        memory: 4Gi
        cpu: 1000m
EOF
  else
    # Individual mode: Monitor only user's labeled namespaces
    cat <<EOF > /tmp/prometheus-values.yaml
grafana:
  adminPassword: admin
  service:
    type: ClusterIP
prometheus:
  service:
    type: ClusterIP
  prometheusSpec:
    # Limit monitoring to user's namespaces for multi-tenancy
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector:
      matchLabels:
        ${MONITORING_LABEL_KEY}: "${MONITORING_LABEL_VALUE}"
    serviceMonitorNamespaceSelector:
      matchLabels:
        ${MONITORING_LABEL_KEY}: "${MONITORING_LABEL_VALUE}"
    podMonitorSelectorNilUsesHelmValues: false
    podMonitorSelector:
      matchLabels:
        ${MONITORING_LABEL_KEY}: "${MONITORING_LABEL_VALUE}"
    podMonitorNamespaceSelector:
      matchLabels:
        ${MONITORING_LABEL_KEY}: "${MONITORING_LABEL_VALUE}"
    maximumStartupDurationSeconds: 300
    # Resource limits for individual monitoring
    resources:
      limits:
        memory: 4Gi
        cpu: 2000m
      requests:
        memory: 2Gi
        cpu: 500m
EOF
  fi

  $HCMD install prometheus prometheus-community/kube-prometheus-stack \
    --namespace "${MONITORING_NAMESPACE}" \
    ${DEBUG} \
    ${CRD_INSTALL_FLAG} \
    -f /tmp/prometheus-values.yaml

  rm -f /tmp/prometheus-values.yaml

  log_info "⏳ Waiting for Prometheus stack pods to be ready..."
  $KCMD wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n "${MONITORING_NAMESPACE}" --timeout=300s || true
  $KCMD wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n "${MONITORING_NAMESPACE}" --timeout=300s || true

  log_success "🚀 Prometheus and Grafana installed."

  # Display access information
  log_info "📊 Access Information:"
  log_info "   Prometheus: kubectl port-forward -n ${MONITORING_NAMESPACE} svc/prometheus-kube-prometheus-prometheus 9090:9090"
  log_info "   Grafana: kubectl port-forward -n ${MONITORING_NAMESPACE} svc/prometheus-grafana 3000:80"
  log_info "   Grafana admin password: admin"
  log_info ""
  log_info "📋 Monitoring Configuration:"
  if [[ "$CENTRAL_MODE" == "true" ]]; then
    log_info "   🌐 Central monitoring: This Prometheus monitors ALL ServiceMonitors and PodMonitors in ALL namespaces"
    log_info "   No namespace labeling is required - all metrics will be collected automatically"
    log_info "   ⚠️  This mode should only be used by cluster administrators or in single-tenant environments"
  else
    log_info "   👤 Individual monitoring: This Prometheus monitors resources labeled with '${MONITORING_LABEL_KEY}: ${MONITORING_LABEL_VALUE}'"
    log_info "   To enable monitoring for your deployments, add this label to your namespaces:"
    log_info "   kubectl label namespace <namespace> ${MONITORING_LABEL_KEY}=${MONITORING_LABEL_VALUE}"
  fi
}

install() {
  if is_openshift; then
    log_info "🔍 OpenShift detected - checking user workload monitoring..."
    if ! check_openshift_monitoring; then
      log_info "⚠️ Metrics collection may not work properly in OpenShift without user workload monitoring enabled."
    fi
    # No Prometheus installation needed if OpenShift monitoring is properly configured
    log_info "ℹ️ Using OpenShift's built-in monitoring stack. No additional Prometheus installation needed."
    log_success "🎉 OpenShift monitoring configuration complete."
  else
    log_info "🔍 Checking for existing ServiceMonitor CRD..."
    if check_servicemonitor_crd; then
      log_info "✅ ServiceMonitor CRD found. Installing namespace-scoped Prometheus stack..."
    else
      log_info "⚠️ ServiceMonitor CRD not found. Installing Prometheus stack with CRDs..."
    fi
    install_prometheus_grafana
    log_success "🎉 Prometheus and Grafana installation complete."
  fi
}

uninstall() {
  log_info "🗑️ Uninstalling Prometheus and Grafana stack..."

  if $HCMD list -n "${MONITORING_NAMESPACE}" | grep -q "prometheus" 2>/dev/null; then
    log_info "🗑️ Uninstalling Prometheus helm release..."
    $HCMD uninstall prometheus --namespace "${MONITORING_NAMESPACE}" || true
  fi

  log_info "🗑️ Deleting monitoring namespace..."
  $KCMD delete namespace "${MONITORING_NAMESPACE}" --ignore-not-found || true

  # Check if we should delete the ServiceMonitor CRD (only if no other Prometheus installations exist)
  if ! $KCMD get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
    log_info "ℹ️ ServiceMonitor CRD not found (already deleted or never installed)"
  else
    log_info "ℹ️ ServiceMonitor CRD still exists (may be used by other monitoring installations)"
    log_info "ℹ️ To manually delete: kubectl delete crd servicemonitors.monitoring.coreos.com"
  fi

  log_success "💀 Uninstallation complete"
}

main() {
  parse_args "$@"
  setup_env
  check_dependencies
  check_cluster_reachability

  if [[ "$ACTION" == "install" ]]; then
    install
  elif [[ "$ACTION" == "uninstall" ]]; then
    uninstall
  else
    die "Unknown action: $ACTION"
  fi
}

main "$@"
