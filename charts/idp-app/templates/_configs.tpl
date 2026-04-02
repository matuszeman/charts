{{- define "idp-app.configName" -}}
{{- $ := index . 0 -}}
{{- $configKey := index . 1 -}}
{{- $configSpec := index $.Values.configs $configKey | required (printf "configs.%s does not exist") -}}
{{- $hash := include "idp-app.configHash" (list $configKey $configSpec)}}
{{- $suffix := "" }}
{{- if and $hash (eq (toString $configSpec.restartPodOnUpdate) "NameSuffix") }}
{{- $suffix = printf "-%s" ($hash | sha1sum | trunc 7) }}
{{- end }}
{{- if $configSpec.fromConfigMap }}
{{- print (tpl $configSpec.fromConfigMap $) $suffix }}
{{- else if $configSpec.fromSecret }}
{{- print (tpl $configSpec.fromSecret $) $suffix }}
{{- else }}
{{- include "idp-app.fullname" $ }}-config-{{ $configKey }}{{ $suffix }}
{{- end }}
{{- end }}
{{- define "idp-app.configHash"}}
{{- $configKey := index . 0 -}}
{{- $configSpec := index . 1 -}}
{{- if $configSpec.valuesHash }}
{{- $configSpec.valuesHash }}
{{- else if $configSpec.awsSecret }}
{{- cat $configSpec.awsSecret.arn $configSpec.awsSecret.versionId | sha1sum }}
{{- else if $configSpec.sealedSecret }}
{{- required "sealedSecret.encryptedData required" (cat $configSpec.sealedSecret.encryptedData) | sha1sum }}
{{- else if $configSpec.content }}
{{- toJson $configSpec.content | sha1sum }}
{{- end }}
{{- end }}
{{- define "idp-app.configsPodAnnotations" -}}
{{- range $configKey, $configSpec := .Values.configs }}
{{ if or (eq (toString $configSpec.restartPodOnUpdate) "true") (eq (toString $configSpec.restartPodOnUpdate) "PodAnnotation") }}
{{- $hash := include "idp-app.configHash" (list $configKey $configSpec)}}
{{ if $hash }}
config-hash-{{ $configKey }}: {{ $hash | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{/*
Render a ConfigMap or Secret from inline content.
Shared by configs.yaml (inline content/secret configs) and _config-files.tpl (fromFolder configs).

Arguments: (list $ $configKey $configSpec)
  $         — root context (.Values must be idp-app values)
  $configKey — config map key
  $configSpec — config spec with .content map; optionally .secret {}, .labels, .annotations,
                .templated, and any other standard config options
*/}}
{{- define "idp-app.renderConfigFromContent" -}}
{{- $ := index . 0 -}}
{{- $configKey := index . 1 -}}
{{- $configSpec := index . 2 -}}
{{- $defaultsConfigsAnnotations := (((($.Values.global).idpAppConfig).defaults).configs).annotations | default (dict) -}}
{{- $mergedLabels := merge (dict) (include "idp-app.labels" $ | fromYaml) (default $configSpec.labels dict) -}}
{{- $mergedAnnotations := merge (dict) $defaultsConfigsAnnotations (default $configSpec.annotations dict) -}}
{{- $isSecret := kindIs "map" $configSpec.secret -}}
---
apiVersion: v1
kind: {{ $isSecret | ternary "Secret" "ConfigMap" }}
metadata:
  name: {{ include "idp-app.configName" (list $ $configKey) }}
  labels:
    {{- toYaml $mergedLabels | nindent 4 }}
  {{- with $mergedAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- if $isSecret }}
type: {{ $configSpec.secret.type | default "Opaque" }}
{{- end }}
data:
{{- range $contentKey, $v := $configSpec.content }}
  {{- $rawValue := $v | required (printf "configs.%s.content.%s required" $configKey $contentKey) }}
  {{- $strValue := "" }}
  {{- if kindIs "map" $rawValue }}
    {{- $strValue = $rawValue | toYaml }}
  {{- else }}
    {{- $strValue = $rawValue | toString }}
  {{- end }}
  {{- $val := "" }}
  {{- if $configSpec.templated }}
  {{- $tplCtx := merge dict (mustDeepCopy $) (dict "configKey" $configKey "configSpec" $configSpec "contentKey" $contentKey) }}
  {{- $val = tpl $strValue $tplCtx }}
  {{- else }}
  {{- $val = $strValue }}
  {{- end }}
  {{ $contentKey }}:
    {{- toYaml ($isSecret | ternary ($val | b64enc) $val) | nindent 4 }}
{{- end }}
{{- end }}
{{- define "idp-app.isConfigUsedInContainersVolumeMounts"}}
{{- /* should be in sync with _pod.tpl config volume mounts, and implemented nicer! */ -}}
{{- $configKeyToCheck := index . 0 -}}
{{- $containers := index . 1 -}}
{{- range $k, $container := $containers }}
{{- with $container.configDirs }}
{{- range $configKey, $v := . }}
{{- if eq $configKeyToCheck $configKey}}
{{- $configKeyToCheck }},
{{- end }}
{{- end }}
{{- end }}
{{- with $container.configFiles }}
{{- range $configKey, $v := . }}
{{- if eq $configKeyToCheck $configKey}}
{{- $configKeyToCheck }},
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}