{{/*
FDQN for Redis master service in <svc_name>.<namespace>.svc.cluster.local:<port> format
*/}}
{{- define "redis.master.service.fullurl" -}}
{{- $name := default (default .Release.Name .Values.redis.nameOverride) .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- $port := default 6379 .Values.redis.master.service.ports.redis -}}
{{- printf "%s-redis-master.%s.svc.cluster.local:%v" $name .Release.Namespace $port -}}
{{- end }}

{{- define "metrics.label" -}}
llmd.ai/gather-metrics: "true"
{{- end }}


{{- define "padString" -}}
{{- $length := len (default "" .text) -}}
{{- if lt .width $length  }}
{{- .text -}}
{{- else -}}
{{- $spacer := default " " .spacer  -}}
{{- .text }}{{- range (until (sub $length .width | int )) -}}{{- print $spacer -}}{{- end -}}
{{- end -}}
{{- end -}}

{{- define "tableRowPrinter" -}}
| {{ include "padString"  ( dict "text" .name "width" .nameWidth "spacer" .spacer ) }} | {{ include "padString"  ( dict "text" .description "width" .descriptionWidth "spacer" .spacer ) }} |
{{- end -}}
