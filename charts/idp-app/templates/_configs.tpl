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