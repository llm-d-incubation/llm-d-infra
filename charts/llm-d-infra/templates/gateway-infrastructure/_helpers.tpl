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

{{/* Grab the gateway service name */}}
{{- define "gateway.serviceName" -}}
  {{- if eq .Values.gateway.gatewayClassName  "istio" -}}
    {{ include "gateway.fullname" . }}-istio
  {{- else }}
    {{ include "gateway.fullname" . }}
  {{- end -}}
{{- end -}}


{{/*
Define the template for ingress host
*/}}
{{- define "gateway.ingressHost" -}}
{{- include "common.tplvalues.render" ( dict "value" .Values.ingress.host "context" $ ) }}
{{- end}}
