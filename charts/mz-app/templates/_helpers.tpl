{{/*
Expand the name of the chart.
*/}}
{{- define "mz-app.name" -}}
{{- required "appName required" .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mz-app.fullname" -}}
{{- if .Values.resourceNameSuffix }}
{{- printf "%s-%s" .Release.Name .Values.resourceNameSuffix | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mz-app.chart" -}}
{{- printf "%s-%s" "mz-app" .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mz-app.labels" -}}
helm.sh/chart: {{ include "mz-app.chart" . }}
{{ include "mz-app.selectorLabels" . }}
app.kubernetes.io/version: {{ required "appVersion required" .Values.appVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mz-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mz-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mz-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mz-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
