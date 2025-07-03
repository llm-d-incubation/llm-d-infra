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
Resolve gateway class name
*/}}
{{- define "gateway.className" -}}
  {{- if contains "gke-l7" .Values.gateway.gatewayClassName -}}
    {{- print .Values.gateway.gatewayClassName -}}
  {{- else -}}
    {{- .Values.gateway.gatewayClassName -}}
  {{- end -}}
{{- end -}}

{{/*
Define the template for ingress host
*/}}
{{- define "gateway.ingressHost" -}}
  {{- if .Values.ingress.host -}}
    {{- include "common.tplvalues.render" ( dict "value" .Values.ingress.host "context" $ ) }}
  {{- else }}
    {{- include "gateway.fullname" . }}.{{ default "localhost" .Values.ingress.clusterRouterBase }}
  {{- end}}
{{- end}}
