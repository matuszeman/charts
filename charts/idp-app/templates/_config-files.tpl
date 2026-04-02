{{/*
Create ConfigMaps from files in a folder of the umbrella chart.
Prefer using idp-app.configsFromFolders which handles iteration automatically.

Low-level usage (single folder):
  {{- include "idp-app.configFilesFromFolder" (list $ctx "configs") }}
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

{{/*
Create ConfigMaps for all configs that use fromFolder in the umbrella chart.
Iterates over idp-app values, finds unique fromFolder values, and calls
idp-app.configFilesFromFolder once per unique folder.

Usage in an umbrella chart template (single line):
  {{- include "idp-app.configsFromFolders" (list . .Values.app) }}

Arguments:
  index 0 — umbrella chart root context (provides .Files for glob/read)
  index 1 — idp-app dependency values (e.g. .Values.app or .Values.myalias)
*/}}
{{- define "idp-app.configsFromFolders" -}}
{{- $root := index . 0 -}}
{{- $values := index . 1 -}}
{{- $ctx := set (mustDeepCopy $root) "Values" $values -}}
{{- $folders := list -}}
{{- range $configKey, $configSpec := $values.configs -}}
{{- if $configSpec.fromFolder -}}
{{- if not (has $configSpec.fromFolder $folders) -}}
{{- $folders = append $folders $configSpec.fromFolder -}}
{{ include "idp-app.configFilesFromFolder" (list $ctx $configSpec.fromFolder) }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}
