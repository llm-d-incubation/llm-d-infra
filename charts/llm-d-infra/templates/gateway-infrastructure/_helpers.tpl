{{/*
Create a default fully qualified app name for inferenceGateway.
*/}}
{{- define "gateway.fullname" -}}
  {{- if .Values.gateway.fullnameOverride -}}
    {{- .Values.gateway.fullnameOverride | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- $name := default "inference-gateway" .Values.gateway.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{/*
Resolve the logical gateway provider used for provider-specific rendering.
*/}}
{{- define "gateway.provider" -}}
  {{- $provider := .Values.gateway.provider | default "" -}}
  {{- $className := .Values.gateway.gatewayClassName | default "" -}}
  {{- $supported := list "istio" "kgateway" "agentgateway" "gke-l7-regional-external-managed" -}}
  {{- if and $provider (not (has $provider $supported)) -}}
    {{- fail (printf "unsupported gateway.provider %q" $provider) -}}
  {{- end -}}
  {{- if $provider -}}
    {{- $provider -}}
  {{- else if or (eq $className "") (eq $className "istio") -}}
    istio
  {{- else if or (eq $className "kgateway") (eq $className "agentgateway") (eq $className "agentgateway-v2") -}}
    agentgateway
  {{- else if eq $className "data-science-gateway-class" -}}
    istio
  {{- else if eq $className "gke-l7-regional-external-managed" -}}
    gke-l7-regional-external-managed
  {{- else -}}
    {{- fail (printf "gateway.provider must be set when using custom gateway.gatewayClassName %q" $className) -}}
  {{- end -}}
{{- end -}}

{{/*
Resolve the literal GatewayClass name attached to the Gateway resource.
*/}}
{{- define "gateway.className" -}}
  {{- $className := .Values.gateway.gatewayClassName | default "" -}}
  {{- if or (eq $className "kgateway") (eq $className "agentgateway-v2") -}}
    agentgateway
  {{- else if $className -}}
    {{- $className -}}
  {{- else -}}
    {{- $provider := include "gateway.provider" . -}}
    {{- if or (eq $provider "kgateway") (eq $provider "agentgateway") -}}
      agentgateway
    {{- else -}}
      {{- $provider -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Return whether the rendered Gateway should use AgentgatewayParameters.
*/}}
{{- define "gateway.usesAgentgatewayParameters" -}}
  {{- $provider := include "gateway.provider" . -}}
  {{- if or (eq $provider "kgateway") (eq $provider "agentgateway") -}}
    true
  {{- else -}}
    false
  {{- end -}}
{{- end -}}

{{/*
Resolve the default exposure intent for the selected provider.
*/}}
{{- define "gateway.defaultExposureType" -}}
  {{- $provider := include "gateway.provider" . -}}
  {{- if or (eq $provider "kgateway") (eq $provider "agentgateway") (eq $provider "gke-l7-regional-external-managed") -}}
    external
  {{- else -}}
    internal
  {{- end -}}
{{- end -}}

{{/*
Resolve the effective exposure intent for the gateway.
*/}}
{{- define "gateway.exposureType" -}}
  {{- $exposureType := .Values.gateway.exposure.type | default "" -}}
  {{- $supported := list "" "internal" "external" -}}
  {{- if not (has $exposureType $supported) -}}
    {{- fail (printf "unsupported gateway.exposure.type %q" $exposureType) -}}
  {{- end -}}
  {{- if $exposureType -}}
    {{- $exposureType -}}
  {{- else -}}
    {{- include "gateway.defaultExposureType" . -}}
  {{- end -}}
{{- end -}}

{{/*
Resolve the effective service type used for gateway-managed Services.
*/}}
{{- define "gateway.serviceType" -}}
  {{- $serviceType := .Values.gateway.service.type | default "" -}}
  {{- $supported := list "" "ClusterIP" "LoadBalancer" "NodePort" -}}
  {{- if not (has $serviceType $supported) -}}
    {{- fail (printf "unsupported gateway.service.type %q" $serviceType) -}}
  {{- end -}}
  {{- if $serviceType -}}
    {{- $serviceType -}}
  {{- else -}}
    {{- $exposureType := include "gateway.exposureType" . -}}
    {{- if eq $exposureType "external" -}}
      LoadBalancer
    {{- else -}}
      ClusterIP
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Grab the gateway service name */}}
{{- define "gateway.serviceName" -}}
  {{- if eq (include "gateway.className" .) "istio" -}}
    {{- printf "%s-istio" (include "gateway.fullname" .) -}}
  {{- else -}}
    {{- include "gateway.fullname" . -}}
  {{- end -}}
{{- end -}}


{{/*
Define the template for ingress host
*/}}
{{- define "gateway.ingressHost" -}}
{{- include "common.tplvalues.render" ( dict "value" .Values.ingress.host "context" $ ) -}}
{{- end -}}
