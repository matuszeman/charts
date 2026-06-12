{{/*
Render Deployment/StatefulSet manifests.
Shared by deployment.yaml, statefulset.yaml (subchart) and umbrella charts.

Usage in an umbrella chart template:
  {{- include "idp-app.workload" (list . .Values.app) }}

Arguments:
  index 0 — root context (.Files used for fromFolder hash computation when available)
  index 1 — idp-app dependency values (e.g. .Values.app or .Values.myalias)

restartPodOnUpdate for fromFolder configs: when called from an umbrella chart, file content
hashes are computed automatically from .Files — no manual valuesHash needed.
When called from the subchart directly, .Files has no umbrella files so hash injection is
skipped (same behaviour as before).
*/}}
{{- define "idp-app.workload" -}}
{{- $root := index . 0 -}}
{{- $values := index . 1 -}}
{{- include "idp-app.injectFromFolderHashes" (list $root $values) -}}
{{- $ctx := set (mustDeepCopy $root) "Values" $values -}}
{{- $kind := include "idp-app.workloadKind" $ctx -}}
{{- $this := fromYaml (include "idp-app.activeWorkload" $ctx) -}}
{{- $deployments := default (dict "" $this) $this.multi }}
{{- range $deploymentKey, $deployment := $deployments }}
{{- $deploymentName := include "idp-app.deploymentName" (list $ctx $deploymentKey) }}
{{- if $deployment.staticIps }}
{{- else }}
apiVersion: apps/v1
kind: {{ $kind }}
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
  {{- if eq $kind "Deployment" }}
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
  {{- else if eq $kind "StatefulSet" }}
  {{- with $this.updateStrategy }}
  updateStrategy:
    type: {{ .type | default "RollingUpdate" }}
    {{- if and (eq (.type | default "RollingUpdate") "RollingUpdate") .rollingUpdate }}
    rollingUpdate:
      {{- toYaml .rollingUpdate | nindent 6 }}
    {{- end }}
  {{- end }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "idp-app.selectorLabels" (list $ctx $deploymentKey) | nindent 6 }}
  revisionHistoryLimit: {{ $this.revisionHistoryLimit }}
  {{- if eq $kind "StatefulSet" }}
  serviceName: {{ $this.serviceName | default (printf "%s-headless" $deploymentName) }}
  {{- with $this.podManagementPolicy }}
  podManagementPolicy: {{ . }}
  {{- end }}
  {{- with $this.minReadySeconds }}
  minReadySeconds: {{ . }}
  {{- end }}
  {{- with $this.ordinals }}
  ordinals:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $this.persistentVolumeClaimRetentionPolicy }}
  persistentVolumeClaimRetentionPolicy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  template:
    {{- include "idp-app.podTemplate" (list $ctx $deploymentKey $deployment) | nindent 4 }}
  {{- if eq $kind "StatefulSet" }}
  {{- $vctEntries := list }}
  {{- range $volumeName, $volumeSpec := $values.volumes }}
  {{- if and $volumeSpec.persistentVolumeClaim (not $volumeSpec.persistentVolumeClaim.claimName) }}
  {{- $vctEntries = append $vctEntries $volumeName }}
  {{- end }}
  {{- end }}
  {{- if $vctEntries }}
  volumeClaimTemplates:
  {{- range $volumeName, $volumeSpec := $values.volumes }}
  {{- if $volumeSpec.persistentVolumeClaim }}
  {{- $pvcSpec := $volumeSpec.persistentVolumeClaim }}
  {{- if not $pvcSpec.claimName }}
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: {{ $volumeName }}
      labels:
        {{- include "idp-app.selectorLabels" (list $ctx $deploymentKey) | nindent 8 }}
      {{- with $pvcSpec.annotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      accessModes:
        - {{ required (printf "volumes.%s.persistentVolumeClaim.accessMode required" $volumeName) $pvcSpec.accessMode }}
      {{- with $pvcSpec.storageClassName }}
      storageClassName: {{ . | quote }}
      {{- end }}
      resources:
        requests:
          storage: {{ required (printf "volumes.%s.persistentVolumeClaim.size required" $volumeName) $pvcSpec.size }}
      {{- with $pvcSpec.selector }}
      selector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $pvcSpec.volumeName }}
      volumeName: {{ . }}
      {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
---
{{- end }}
{{- end }}
{{- end }}
