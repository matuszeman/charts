{{/*
Create ConfigMaps from files in a folder of the umbrella chart.
Usage in an umbrella chart template:
  {{- $ctx := set (mustDeepCopy . ) "Values" .Values.app }}
  {{ include "idp-app.configFilesFromFolder" (list $ctx "configs") }}
Each file <folder>/<name>.<ext> becomes a ConfigMap named <fullname>-config-<name>.
The folder can be any path relative to the umbrella chart root.
*/}}
{{- define "idp-app.configFilesFromFolder" -}}
{{- $ := index . 0 -}}
{{- $folder := index . 1 -}}
{{- range $path, $_ := $.Files.Glob (printf "%s/*" $folder) }}
{{- $filename := base $path }}
{{- $name := trimSuffix (ext $filename) $filename }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "idp-app.fullname" $ }}-config-{{ $name }}
  labels:
    {{- include "idp-app.labels" $ | nindent 4 }}
data:
  {{ $filename }}: |
{{ $.Files.Get $path | indent 4 }}
{{- end }}
{{- end }}
