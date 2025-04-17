{{- define "idp-app.configName" -}}
{{- $ := index . 0 -}}
{{- $configKey := index . 1 -}}
{{- $configSpec := index $.Values.configs $configKey | required (printf "configs.%s does not exist") -}}
{{- $hash := include "idp-app.configHash" (list $configKey $configSpec)}}
{{- $suffix := "" }}
{{- if and $hash $configSpec.hashSuffix }}
{{- $suffix = printf "-%s" $hash }}
{{- end }}
{{- include "idp-app.fullname" $ }}-config-{{ $configKey }}{{ $suffix }}
{{- end }}
{{- define "idp-app.configHash"}}
{{- $configKey := index . 0 -}}
{{- $configSpec := index . 1 -}}
{{- if or $configSpec.fromSecret $configSpec.fromConfigMap }}
{{- else if $configSpec.awsSecret }}
{{- required "awsSecret.arn required" (cat $configSpec.awsSecret.arn $configSpec.awsSecret.versionId $configSpec.awsSecret.updateHash)  | sha256sum | trunc 7 }}
{{- else if $configSpec.sealedSecret }}
{{- required "sealedSecret.encryptedData required" (cat $configSpec.sealedSecret.encryptedData) | sha256sum | trunc 7 }}
{{- else if $configSpec.content }}
{{- toJson $configSpec.content | sha256sum | trunc 7 }}
{{- end }}
{{- end }}
{{- define "idp-app.configsPodAnnotations" -}}
{{- range $configKey, $configSpec := .Values.configs }}
{{ if $configSpec.restartPodOnUpdate }}
{{- $hash := include "idp-app.configHash" (list $configKey $configSpec)}}
{{ if $hash }}
config-{{ $configKey }}-hash: {{ $hash | quote }}
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