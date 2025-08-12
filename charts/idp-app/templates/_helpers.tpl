{{/*
Expand the name of the chart.
*/}}
{{- define "idp-app.name" -}}
{{- required "appName required" .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "idp-app.fullname" -}}
{{- if .Values.resourceNameSuffix }}
{{- printf "%s-%s" .Release.Name (tpl .Values.resourceNameSuffix .) | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "idp-app.deploymentName" -}}
{{- $ := index . 0 -}}
{{- $deploymentKey := index . 1 -}}
{{- empty $deploymentKey | ternary (include "idp-app.fullname" $) (printf "%s-%s" (include "idp-app.fullname" $) $deploymentKey) }}
{{- end }}

{{/*

{{/*
Create chart name and version as used by the chart label.
*/}}
{{/*{{- define "idp-app.chart" -}}*/}}
{{/*{{- printf "%s-%s" "idp-app" .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}*/}}
{{/*{{- end }}*/}}

{{/*
Common labels
*/}}
{{- define "idp-app.labels" -}}
{{/*helm.sh/chart: {{ include "idp-app.chart" . }}*/}}
{{- include "idp-app.selectorLabels" (list . "") }}
app.kubernetes.io/version: {{ tpl (required "appVersion required" .Values.appVersion) . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "idp-app.selectorLabels" -}}
{{- $ := index . 0 -}}
{{- $deploymentName := index . 1 -}}
app.kubernetes.io/name: {{ include "idp-app.name" $ }}
app.kubernetes.io/instance: {{ include "idp-app.fullname" $ }}{{ if $deploymentName }}-{{ $deploymentName }}{{ end }}
{{- end }}

{{- define "idp-app.oauth2ProxySelectorLabels" -}}
{{- $ := index . 0 -}}
app.kubernetes.io/name: {{ include "idp-app.name" $ }}-oauth2-proxy
app.kubernetes.io/instance: {{ include "idp-app.fullname" $ }}
{{- end }}


{{/*
Create the name of the service account to use
*/}}
{{- define "idp-app.serviceAccountName" -}}
{{- default (include "idp-app.fullname" .) .Values.serviceAccount.name }}
{{- end }}
