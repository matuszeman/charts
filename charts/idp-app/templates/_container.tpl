{{/*
Container manifest
*/}}
{{- define "idp-app.container" -}}
{{- $ := index . 1 -}}
{{- with index . 0 -}}
{{- $containerName := required (cat .name "container: name required") .name -}}
{{- $imageRepoKey := default $.Values.global.idpAppConfig.defaults.imageRepository .imageRepository -}}
name: {{ $containerName }}
{{- if .securityContext }}
securityContext:
{{- toYaml .securityContext | nindent 2 }}
{{- end }}
image: "{{ required (printf "imageRepository %s not specified in global.idpAppConfig.imageRepositories" $imageRepoKey ) (index $.Values.global.idpAppConfig.imageRepositories $imageRepoKey) }}/{{ required "image required" .image }}:{{ tpl (required "imageTag required" .imageTag) $ }}"
imagePullPolicy: {{ default .imagePullPolicy $.Values.global.idpAppConfig.defaults.imagePullPolicy }}
{{- with .command }}
command:
{{- range . }}
- {{ . | quote }}
{{- end }}
{{- end }}
{{- with .args }}
args:
{{- range . }}
- {{ . | quote }}
{{- end }}
{{- end }}
{{- if or (and $.Values.service.enabled (eq $containerName "app")) .containerPort }}
ports:
- name: {{ $containerName }}
  containerPort: {{ required (cat $containerName "container: containerPort required") .containerPort }}
  protocol: {{ .containerPortProtocol | default "TCP" }}
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
{{- with .lifecycle }}
lifecycle:
{{- toYaml . | nindent 2 }}
{{- end }}
resources:
  {{- with .resources.limits }}
  limits:
    {{- with .cpu }}
    cpu: {{ . }}
    {{- end }}
    {{- with .memory }}
    memory: {{ . }}
    {{- end }}
    {{- with .ephemeralStorage }}
    ephemeral-storage: {{ . }}
    {{- end }}
  {{- end }}
  requests:
    cpu: {{ required (cat "container " $containerName ": resources.requests.cpu required") .resources.requests.cpu }}
    memory: {{ required (cat "container " $containerName ": resources.requests.memory required") .resources.requests.memory }}
    {{- with .resources.requests.ephemeralStorage }}
    ephemeral-storage: {{ . }}
    {{- end }}
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
    {{- if or $config.fromSecret $config.awsSecret $config.sealedSecret }}
    secretKeyRef:
      name: {{ include "idp-app.configName" (list $ $configRef.name) }}
      key: {{ $configRef.key }}
    {{- else if or $config.fromConfigMap $config.content }}
    configMapKeyRef:
      name: {{ include "idp-app.configName" (list $ $configRef.name) }}
      key: {{ $configRef.key }}
    {{- else }}
    {{- required ( printf "configs.%s does not specify fromConfigMap, fromSecret, awsSecret, sealedSecret, nor content" $k ) nil }}
    {{- end }}
    {{- end }}
    {{- else }}
    {{- toYaml $v | nindent 4 }}
    {{- end}}
  {{- end }}
{{- end }}
{{- end }}

{{- if or .configDirs .configFiles .volumeMounts .volumeFiles }}
volumeMounts:
{{- with .configDirs }}
{{- /* should be in sync with _configs.tpl idp-app.isConfigUsedInContainersVolumeMounts template */}}
{{- range $configKey, $v := . }}
{{- $_ := required (printf "configDirs: %s must be specified in 'configs' values." $configKey) (index $.Values.configs $configKey) }}
  - name: config-{{ $configKey }}
    mountPath: {{ required "configDir path required" $v }}
    readOnly: true
{{- end }}
{{- end }}

{{- with .configFiles }}
{{- /* should be in sync with _configs.tpl idp-app.isConfigUsedInContainersVolumeMounts template */}}
{{- range $configKey, $v := . }}
{{- $_ := required (printf "configFiles: %s must be specified in 'configs' values." $configKey) (index $.Values.configs $configKey) }}
{{- range $configValueKey, $mountPath := . }}
  - name: config-{{ $configKey }}
    mountPath: {{ required (cat "container " $containerName ": configDir path required") $mountPath }}
    subPath: {{ required (cat "container " $containerName ": configDir subPath required") $configValueKey }}
    readOnly: true
{{- end }}
{{- end }}
{{- end }}
{{- with .volumeMounts }}
{{- range $name, $volumeSpec := . }}
{{- $_ := required (printf "volumeMounts: %s must be specified in 'volumes' values." $name) (index $.Values.volumes $name) }}
  - name: {{ $name }}
    mountPath: {{ required (cat "container " $containerName ": .volumeMounts mountPath required") $volumeSpec.mountPath }}
    readOnly: {{ ternary "true" "false" (default false $volumeSpec.readOnly) }}
{{- end }}
{{- end }}
{{- with .volumeFiles }}
{{- range $name, $v := . }}
{{- $_ := required (printf "volumeFiles: %s must be specified in 'volumes' values." $name) (index $.Values.volumes $name) }}
{{- range $file, $volumeSpec := . }}
  - name: {{ $name }}
    mountPath: {{ required (cat "container " $containerName ": volumeFiles mountPath required") $volumeSpec.mountPath }}
    subPath: {{ required (cat "container " $containerName ": volumeFiles subPath required") $file }}
    readOnly: {{ ternary $volumeSpec.readOnly "true" (hasKey $volumeSpec "readOnly") }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}

{{- end }}
{{- end }}