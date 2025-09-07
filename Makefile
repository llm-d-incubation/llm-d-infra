SHELL := /usr/bin/env bash

# Defaults
NAMESPACE ?= hc4ai-operator
CHART ?= charts/llm-d-infra


.PHONY: help
help: ## Print help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9%-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: pre-helm
pre-helm:
	helm repo add bitnami https://charts.bitnami.com/bitnami

.PHONY: helm-lint
helm-lint: pre-helm ## Run helm lint on the specified chart
	@printf "\033[33;1m==== Running helm lint ====\033[0m\n"
	ct lint

.PHONY: helm-template
helm-template: pre-helm ## Render chart templates without installing
	@printf "\033[33;1m==== Running helm template ====\033[0m\n"
	helm template $(RELEASE) $(CHART) --namespace $(NAMESPACE)

.PHONY: helm-install
helm-install: pre-helm ## Install the chart into the given namespace
	@printf "\033[33;1m==== Running helm install ====\033[0m\n"
	helm install $(RELEASE) $(CHART) --namespace $(NAMESPACE) --create-namespace

.PHONY: helm-upgrade
helm-upgrade: pre-helm ## Upgrade the release if it exists
	@printf "\033[33;1m==== Running helm upgrade ====\033[0m\n"
	helm upgrade --install $(RELEASE) $(CHART) --namespace $(NAMESPACE) --create-namespace

.PHONY: helm-uninstall
helm-uninstall: ## Uninstall the Helm release
	@printf "\033[33;1m==== Running helm uninstall ====\033[0m\n"
	helm uninstall $(RELEASE) --namespace $(NAMESPACE)


##@ Automation

.PHONY: bump-chart-version-%
bump-chart-version-%:  ## Bump chart version by type (patch, major, minor)
	@printf "\033[33;1m==== Running bump chart version ====\033[0m\n"
	helpers/scripts/increment-chart-version.sh $*
