{{/*
Create ConfigMaps (or Secrets) for all configs that use fromFolder in the umbrella chart.
Reads files from the specified folder, builds the content map, and delegates rendering
to idp-app.renderConfigFromContent — supporting all config features: secret, templated,
labels, annotations, etc.

Usage in an umbrella chart template (single line):
  {{- include "idp-app.configsFromFolders" (list . .Values.app) }}

Arguments:
  index 0 — umbrella chart root context (provides .Files for glob/read)
  index 1 — idp-app dependency values (e.g. .Values.app or .Values.myalias)

Note: restartPodOnUpdate is not supported for fromFolder configs because file content
is not available in the idp-app values context used by pod template helpers.
*/}}
{{- define "idp-app.configsFromFolders" -}}
{{- $root := index . 0 -}}
{{- $values := index . 1 -}}
{{- $ctx := set (mustDeepCopy $root) "Values" $values -}}
{{- range $configKey, $configSpec := $values.configs -}}
{{- if $configSpec.fromFolder -}}
{{- $content := dict -}}
{{- range $path, $_ := $root.Files.Glob (printf "%s/*" $configSpec.fromFolder) -}}
{{- $content = set $content (base $path) ($root.Files.Get $path) -}}
{{- end -}}
{{- $mergedSpec := merge (mustDeepCopy $configSpec) (dict "content" $content) }}
{{ include "idp-app.renderConfigFromContent" (list $ctx $configKey $mergedSpec) }}
{{- end -}}
{{- end -}}
{{- end }}
