{{/*
Render Deployment/StatefulSet manifests.
Shared by deployment.yaml (subchart) and umbrella charts.

Usage in an umbrella chart template:
  {{- include "idp-app.deployments" (list . .Values.app) }}

Arguments:
  index 0 — root context (.Files used for fromFolder hash computation when available)
  index 1 — idp-app dependency values (e.g. .Values.app or .Values.myalias)

restartPodOnUpdate for fromFolder configs: when called from an umbrella chart, file content
hashes are computed automatically from .Files — no manual valuesHash needed.
When called from the subchart directly, .Files has no umbrella files so hash injection is
skipped (same behaviour as before).
*/}}
{{- define "idp-app.deployments" -}}
{{- $root := index . 0 -}}
{{- $values := index . 1 -}}
{{- /* Inject file-content hashes for fromFolder configs with restartPodOnUpdate */ -}}
{{- range $configKey, $configSpec := $values.configs -}}
{{- if and $configSpec.fromFolder (not $configSpec.valuesHash) -}}
{{- if or (eq (toString $configSpec.restartPodOnUpdate) "true") (eq (toString $configSpec.restartPodOnUpdate) "PodAnnotation") (eq (toString $configSpec.restartPodOnUpdate) "NameSuffix") -}}
{{- $content := dict -}}
{{- range $path, $_ := $root.Files.Glob (printf "%s/*" $configSpec.fromFolder) -}}
{{- $content = set $content (base $path) ($root.Files.Get $path) -}}
{{- end -}}
{{- if $content -}}
{{- $_ := set (index $values.configs $configKey) "valuesHash" (toJson $content | sha1sum) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $ctx := set (mustDeepCopy $root) "Values" $values -}}
{{- $this := $values.deployment -}}
{{- if not (has $this.kind (list "Deployment" "StatefulSet")) }}
  {{- fail "deployment.kind must be Deployment or StatefulSet" }}
{{- end }}
{{- $deployments := default (dict "" $this) $this.multi }}
{{- range $deploymentKey, $deployment := $deployments }}
{{- $deploymentName := include "idp-app.deploymentName" (list $ctx $deploymentKey) }}
{{- if $deployment.staticIps }}
{{- else }}
apiVersion: apps/v1
kind: {{ $this.kind }}
metadata:
  name: {{ $deploymentName }}
  labels:
    {{- include "idp-app.labelsMulti" (list $ctx $deploymentKey) | nindent 4 }}
  {{- with $this.annotations }}
  annotations:
    {{- toYaml $this.annotations | nindent 4 }}
  {{- end }}
spec:
  {{- if not $values.autoscaling.enabled }}
  replicas: {{ $values.replicaCount }}
  {{- end }}
  {{- with $this.strategy }}
  {{- if not (has .type (list "RollingUpdate" "Recreate")) }}
    {{- fail "deployment.strategy.type must be RollingUpdate or Recreate" }}
  {{- end }}
  strategy:
    type: {{ .type }}
    {{- if eq .type "RollingUpdate" }}
    {{- if .rollingUpdate }}
    rollingUpdate:
      {{- toYaml .rollingUpdate | nindent 6 }}
    {{- end }}
    {{- else }}
    rollingUpdate: null
    {{- end }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "idp-app.selectorLabels" (list $ctx $deploymentKey) | nindent 6 }}
  revisionHistoryLimit: {{ $this.revisionHistoryLimit }}
  template:
    {{- include "idp-app.podTemplate" (list $ctx $deploymentKey $deployment) | nindent 4 }}
---
{{- end }}
{{- end }}
{{- end }}
