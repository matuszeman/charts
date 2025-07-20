{{- define "idp-app.podTemplate" -}}
{{- $ := index . 0 -}}
{{- $deploymentKey := index . 1 -}}
{{- $deployment := index . 2 -}}
{{- $containers := mustMergeOverwrite (deepCopy $.Values.containers) (deepCopy (default dict $deployment.containers)) }}
metadata:
  {{ $podAnnotations := merge (dict) $.Values.podAnnotations (fromYaml (include "idp-app.configsPodAnnotations" $)) }}
  {{- with $podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "idp-app.selectorLabels" (list $ $deploymentKey) | nindent 4 }}
spec:
  {{- $restartPolicy := $.Values.restartPolicy }}
  {{- if and (not $.Values.restartPolicy) (or $.Values.cronjob.enabled $.Values.job.enabled) }}
  {{- $restartPolicy = "OnFailure" }}
  {{- end }}
  {{- with $restartPolicy }}
  restartPolicy: {{ $restartPolicy }}
  {{- end }}
  {{- with $.Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "idp-app.serviceAccountName" $ }}
  securityContext:
    # This is needed for containerd runtime, docker previously allowed binding to 80 port
    sysctls:
      - name: net.ipv4.ip_unprivileged_port_start
        value: "0"
  {{- with $.Values.terminationGracePeriodSeconds }}
  terminationGracePeriodSeconds: {{ . }}
  {{- end }}
  {{- if not $.Values.enableServiceLinks }}
  enableServiceLinks: {{ $.Values.enableServiceLinks }}
  {{- end }}
  containers:
    {{- $_ := required "containers.app required" $.Values.containers.app -}}
    {{- with $.Values.containers }}
    {{- range $k, $v := $containers }}
    - {{- include "idp-app.container" ( list (merge (dict "name" $k) $v ) $ ) | nindent 6 }}
    {{- end }}
    {{- end }}
  volumes:
    {{- with $.Values.configs }}
    {{- range $configKey, $v := . }}
    {{- if empty (include "idp-app.isConfigUsedInContainersVolumeMounts" (list $configKey $containers)) }}
    {{- else }}
    - name: config-{{ $configKey }}
      {{- if or $v.fromSecret $v.awsSecret $v.sealedSecret }}
      secret:
        secretName: {{ include "idp-app.configName" (list $ $configKey) }}
        {{- with $v.defaultMode }}
        defaultMode: {{ . }}
        {{- end }}
      {{- else if or $v.fromConfigMap $v.content }}
      configMap:
        name: {{ include "idp-app.configName" (list $ $configKey) }}
        {{- with $v.defaultMode }}
        defaultMode: {{ . }}
        {{- end }}
      {{- else }}
      {{- required ( printf "configs.%s does not specify fromConfigMap, fromSecret, awsSecret, sealedSecret nor content" $configKey ) nil }}
      {{- end }}
    {{- end }}
    {{- end }}
    {{- end }}
    {{- with $.Values.volumes }}
    {{- range $name, $spec := . }}
    - name: {{ $name }}
      {{- toYaml $spec | nindent 6 }}
    {{- end }}
    {{- end }}
  nodeSelector:
    {{- with (index $.Values.global.idpAppConfig.clusters $.Values.global.cluster).nodeSelector }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- if eq $.Values.nodeCapacity.type "OnDemand" }}
    capacity: on-demand
    {{- end }}
    {{- if $.Values.nodeSelector }}
    {{- toYaml $.Values.nodeSelector | nindent 4 }}
    {{- end }}
  {{- with $.Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  topologySpreadConstraints:
    {{- if $.Values.topologySpreadConstraints.zone }}
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          {{- include "idp-app.selectorLabels" (list $ $deploymentKey) | nindent 10 }}
    {{- end }}
    {{- if $.Values.topologySpreadConstraints.node }}
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          {{- include "idp-app.selectorLabels" (list $ $deploymentKey) | nindent 10 }}
    {{- end }}
  tolerations:
    {{- with (index $.Values.global.idpAppConfig.clusters $.Values.global.cluster).tolerations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- if eq $.Values.nodeCapacity.type "OnDemand" }}
    - key: capacity
      operator: Equal
      value: on-demand
      effect: NoSchedule
    {{- end }}

{{- end }}