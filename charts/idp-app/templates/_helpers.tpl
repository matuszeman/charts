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

{{/*
Resolve HPA scale direction behavior.
Args: (list $vals $presetDefs $direction)
  $vals       - autoscaling.scaleDown or autoscaling.scaleUp dict
  $presetDefs - global.idpAppConfig.defaults.autoscaling.presets.scaleDown|scaleUp dict
  $direction  - "scaleDown" or "scaleUp" (used in error messages only)
Returns YAML for the resolved behavior, or empty string if nothing to render.
*/}}
{{- define "idp-app.hpaScaleDir" -}}
{{- $vals := index . 0 -}}
{{- $presetDefs := index . 1 -}}
{{- $direction := index . 2 -}}
{{- $overrides := omit $vals "preset" -}}
{{- $preset := $vals.preset -}}
{{- if $preset -}}
{{- $def := index $presetDefs $preset -}}
{{- if not $def -}}{{ fail (printf "autoscaling.%s.preset '%s' not defined in global.idpAppConfig.defaults.autoscaling.presets.%s" $direction $preset $direction) }}{{- end -}}
{{- toYaml (mustMergeOverwrite (deepCopy $def) $overrides) -}}
{{- else if $overrides -}}
{{- toYaml $overrides -}}
{{- end -}}
{{- end -}}

{{- define "idp-app.deploymentName" -}}
{{- $ := index . 0 -}}
{{- $deploymentKey := index . 1 -}}
{{- empty $deploymentKey | ternary (include "idp-app.fullname" $) (printf "%s-%s" (include "idp-app.fullname" $) $deploymentKey) }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "idp-app.labels" -}}
{{- include "idp-app.selectorLabels" (list . "") }}
app.kubernetes.io/version: {{ tpl (required "appVersion required" .Values.appVersion) . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "idp-app.labelsMulti" -}}
{{- $ := index . 0 -}}
{{- $deploymentName := index . 1 -}}
{{- include "idp-app.selectorLabels" (list $ $deploymentName) }}
app.kubernetes.io/version: {{ tpl (required "appVersion required" $.Values.appVersion) $ }}
app.kubernetes.io/managed-by: {{ $.Release.Service }}
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

{{- define "idp-app.clusterConfig" }}
{{- $ := . }}
{{- $cluster := (index $.Values.global.idpAppConfig.clusters $.Values.global.cluster) | required "idp-app.clusterConfig: cluster does not exist in cluster list" }}
{{- toYaml $cluster }}
{{- end }}
{{- define "idp-app.clusterConfigMapValue" }}
{{- $ := index . 0 }}
{{- $key := index . 1 | required "idp-app.clusterConfigMapValue: cluster config key param required" }}
{{- $index := index . 2 | required (printf "idp-app.clusterConfigMapValue: key param for cluster config '%s' required" $key) }}
{{- $cluster := include "idp-app.clusterConfig" $ | fromYaml }}
{{- index (index $cluster $key | required (printf "global.idpAppConfig.clusters.%s.%s is not defined" $.Values.global.cluster $key)) $index | required (printf "global.idpAppConfig.clusters.%s.%s.%s is not defined" $.Values.global.cluster $key $index) | toYaml }}
{{- end }}
{{/*
Resolve a hostname from a domain value and an optional host prefix.
Domain may contain a generic <HOST{sep}> placeholder (e.g. <HOST.>, <HOST->, <HOST_>).
When host is set: placeholder is replaced by "{host}{sep}".
When host is empty: placeholder is removed entirely.
When domain has no placeholder: host is prepended with "." separator (legacy behaviour).
*/}}
{{- define "idp-app.resolveHostFromDomain" -}}
{{- $host := index . 0 -}}
{{- $domain := index . 1 -}}
{{- if regexMatch "<HOST[^>]*>" $domain -}}
  {{- if $host -}}
    {{- regexReplaceAll "<HOST([^>]*)>" $domain (printf "%s${1}" $host) -}}
  {{- else -}}
    {{- regexReplaceAll "<HOST[^>]*>" $domain "" -}}
  {{- end -}}
{{- else -}}
  {{- if $host -}}
    {{- printf "%s.%s" $host $domain -}}
  {{- else -}}
    {{- $domain -}}
  {{- end -}}
{{- end -}}
{{- end -}}
