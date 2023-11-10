{{/*
Container manifest
*/}}
{{- define "mz-app.container" -}}
{{- $ := index . 1 -}}
{{- with index . 0 -}}
{{- $imageRepoKey := default $.Values.global.settings.defaults.imageRepository .imageRepository -}}
name: {{ required ".name required" .name }}
{{- if .securityContext }}
securityContext:
{{- toYaml .securityContext | nindent 2 }}
{{- end }}
image: "{{ required (printf "imageRepository %s not specified in global.settings.imageRepositories" $imageRepoKey ) (index $.Values.global.settings.imageRepositories $imageRepoKey) }}/{{ required "image required" .image }}:{{ required "imageTag required" .imageTag }}"
imagePullPolicy: {{ default .imagePullPolicy $.Values.global.settings.defaults.imagePullPolicy }}
ports:
{{- if $.Values.service.enabled }}
- name: {{ required "name required" .name }}
  containerPort: {{ required "containerPort required" .containerPort }}
  protocol: TCP
{{- end }}
{{- with .additionalPorts }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- with .livenessProbe }}
livenessProbe:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- with .readinessProbe }}
readinessProbe:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- with .startupProbe }}
startupProbe:
{{- toYaml . | nindent 2 }}
{{- end }}
resources:
  limits:
    cpu: {{ required "resources.limits.cpu required" .resources.limits.cpu }}
    memory: {{ required "resources.limits.memory required" .resources.limits.memory }}
  requests:
    cpu: {{ required "resources.requests.cpu required" .resources.requests.cpu }}
    memory: {{ required "resources.requests.memory required" .resources.requests.memory }}
{{- with .env }}
env:
{{- range $k, $v := . }}
- name: {{ $k }}
  {{- if or (kindIs "string" $v) (kindIs "int" $v) (kindIs "float64" $v) (kindIs "bool" $v) }}
  value: {{ tpl ($v | toString) $ | quote }}
  {{- else }}
  valueFrom:
    {{- if hasKey $v "secretKeyRef" }}
    secretKeyRef:
      name: {{ tpl $v.secretKeyRef.name $ }}
      key: {{ $v.secretKeyRef.key }}
    {{- else if hasKey $v "configMapKeyRef" }}
    configMapKeyRef:
      name: {{ tpl $v.configMapKeyRef.name $ }}
      key: {{ $v.configMapKeyRef.key }}
    {{- else if hasKey $v "config" }}
    {{- with $configRef := $v.config }}
    {{- $config := required (printf "env: %s must be specified in 'configs' values."  $configRef.name) (index $.Values.configs $configRef.name) }}
    {{- if $config.fromConfigMap }}
    configMapKeyRef:
      name: {{ tpl $config.fromConfigMap $ }}
      key: {{ $configRef.key }}
    {{- else if $config.fromSecret }}
    secretKeyRef:
      name: {{ tpl $config.fromSecret $ }}
      key: {{ $configRef.key }}
    {{- else if $config.awsSecret }}
    secretKeyRef:
      name: {{ printf "%s-config-%s" (include "mz-app.fullname" $ ) $configRef.name }}
      key: {{ $configRef.key }}
    {{- else if $config.content }}
    configMapKeyRef:
      name: {{ printf "%s-config-%s" (include "mz-app.fullname" $ ) $configRef.name }}
      key: {{ $configRef.key }}
    {{- else }}
    {{- required ( printf "configs.%s does not specify fromConfigMap, fromSecret, awsSecret, nor content" $k ) nil }}
    {{- end }}
    {{- end }}
    {{- else }}
    {{- toYaml $v | nindent 4 }}
    {{- end}}
  {{- end }}
{{- end }}
{{- end }}

{{- if or .configDirs .configFiles .volumeMounts }}
volumeMounts:
{{- with .configDirs }}
{{- range $configKey, $v := . }}
{{- $_ := required (printf "configDirs: %s must be specified in 'configs' values." $configKey) (index $.Values.configs $configKey) }}
  - name: config-{{ $configKey }}
    mountPath: {{ required "configDir path required" $v }}
    readOnly: true
{{- end }}
{{- end }}

{{- with .configFiles }}
{{- range $configKey, $v := . }}
{{- $_ := required (printf "configFiles: %s must be specified in 'configs' values." $configKey) (index $.Values.configs $configKey) }}
{{- range $configValueKey, $mountPath := . }}
  - name: config-{{ $configKey }}
    mountPath: {{ required "configDir path required" $mountPath }}
    subPath: {{ required "configDir subPath required" $configValueKey }}
    readOnly: true
{{- end }}
{{- end }}
{{- end }}
{{- with .volumeMounts }}
{{- range $name, $volumeSpec := . }}
{{- $_ := required (printf "volumeMounts: %s must be specified in 'volumes' values." $name) (index $.Values.volumes $name) }}
  - name: {{ $name }}
    mountPath: {{ required ".volumeMounts mountPath required" $volumeSpec.mountPath }}
    readOnly: {{ ternary "true" "false" (default false $volumeSpec.readOnly) }}
{{- end }}
{{- end }}

{{- end }}

{{- end }}
{{- end }}