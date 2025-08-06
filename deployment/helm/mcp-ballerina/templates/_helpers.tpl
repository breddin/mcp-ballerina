{{/*
Expand the name of the chart.
*/}}
{{- define "mcp-ballerina.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mcp-ballerina.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mcp-ballerina.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mcp-ballerina.labels" -}}
helm.sh/chart: {{ include "mcp-ballerina.chart" . }}
{{ include "mcp-ballerina.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mcp-ballerina
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mcp-ballerina.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcp-ballerina.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: server
{{- end }}

{{/*
Common annotations
*/}}
{{- define "mcp-ballerina.annotations" -}}
{{- with .Values.global.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mcp-ballerina.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mcp-ballerina.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "mcp-ballerina.secretName" -}}
{{- if .Values.secrets.existingSecret }}
{{- .Values.secrets.existingSecret }}
{{- else }}
{{- printf "%s-secrets" (include "mcp-ballerina.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap to use
*/}}
{{- define "mcp-ballerina.configMapName" -}}
{{- printf "%s-config" (include "mcp-ballerina.fullname" .) }}
{{- end }}

{{/*
Create the name of the scripts configmap to use
*/}}
{{- define "mcp-ballerina.scriptsConfigMapName" -}}
{{- printf "%s-scripts" (include "mcp-ballerina.fullname" .) }}
{{- end }}

{{/*
Create database URL
*/}}
{{- define "mcp-ballerina.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql://%s:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password .Release.Name .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.secrets.database.url }}
{{- end }}
{{- end }}

{{/*
Create Redis URL
*/}}
{{- define "mcp-ballerina.redisUrl" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.auth.enabled }}
{{- printf "redis://:%s@%s-redis-master:6379/0" .Values.redis.auth.password .Release.Name }}
{{- else }}
{{- printf "redis://%s-redis-master:6379/0" .Release.Name }}
{{- end }}
{{- else }}
{{- .Values.secrets.redis.url }}
{{- end }}
{{- end }}

{{/*
Get image registry
*/}}
{{- define "mcp-ballerina.imageRegistry" -}}
{{- $registry := .Values.image.registry -}}
{{- if .Values.global.imageRegistry -}}
{{- $registry = .Values.global.imageRegistry -}}
{{- end -}}
{{- $registry -}}
{{- end -}}

{{/*
Get full image name
*/}}
{{- define "mcp-ballerina.image" -}}
{{- $registry := include "mcp-ballerina.imageRegistry" . -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end -}}

{{/*
Get nginx image name
*/}}
{{- define "mcp-ballerina.nginxImage" -}}
{{- $registry := .Values.nginx.image.registry -}}
{{- if .Values.global.imageRegistry -}}
{{- $registry = .Values.global.imageRegistry -}}
{{- end -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .Values.nginx.image.repository .Values.nginx.image.tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.nginx.image.repository .Values.nginx.image.tag -}}
{{- end -}}
{{- end -}}

{{/*
Get image pull policy
*/}}
{{- define "mcp-ballerina.imagePullPolicy" -}}
{{- .Values.image.pullPolicy | default "IfNotPresent" -}}
{{- end -}}

{{/*
Get storage class name
*/}}
{{- define "mcp-ballerina.storageClassName" -}}
{{- $storageClass := "" -}}
{{- if .Values.global.storageClass -}}
{{- $storageClass = .Values.global.storageClass -}}
{{- else if .storageClass -}}
{{- $storageClass = .storageClass -}}
{{- end -}}
{{- $storageClass -}}
{{- end -}}

{{/*
Validate required values
*/}}
{{- define "mcp-ballerina.validateValues" -}}
{{- if not .Values.image.repository -}}
{{- fail "image.repository is required" -}}
{{- end -}}
{{- if not .Values.image.tag -}}
{{- if not .Chart.AppVersion -}}
{{- fail "image.tag or Chart.AppVersion is required" -}}
{{- end -}}
{{- end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.hosts) -}}
{{- fail "ingress.hosts is required when ingress is enabled" -}}
{{- end -}}
{{- end -}}

{{/*
Create pod security context
*/}}
{{- define "mcp-ballerina.podSecurityContext" -}}
{{- if .Values.global.securityContext.enabled -}}
runAsNonRoot: {{ .Values.deployment.podSecurityContext.runAsNonRoot | default .Values.global.securityContext.runAsNonRoot }}
runAsUser: {{ .Values.deployment.podSecurityContext.runAsUser | default .Values.global.securityContext.runAsUser }}
runAsGroup: {{ .Values.deployment.podSecurityContext.runAsGroup | default .Values.global.securityContext.runAsGroup }}
fsGroup: {{ .Values.deployment.podSecurityContext.fsGroup | default .Values.global.securityContext.fsGroup }}
{{- with .Values.deployment.podSecurityContext.seccompProfile }}
seccompProfile:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Create container security context
*/}}
{{- define "mcp-ballerina.securityContext" -}}
{{- if .Values.global.securityContext.enabled -}}
allowPrivilegeEscalation: {{ .Values.deployment.securityContext.allowPrivilegeEscalation | default false }}
readOnlyRootFilesystem: {{ .Values.deployment.securityContext.readOnlyRootFilesystem | default true }}
runAsNonRoot: {{ .Values.deployment.securityContext.runAsNonRoot | default .Values.global.securityContext.runAsNonRoot }}
runAsUser: {{ .Values.deployment.securityContext.runAsUser | default .Values.global.securityContext.runAsUser }}
runAsGroup: {{ .Values.deployment.securityContext.runAsGroup | default .Values.global.securityContext.runAsGroup }}
{{- with .Values.deployment.securityContext.capabilities }}
capabilities:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Create image pull secrets
*/}}
{{- define "mcp-ballerina.imagePullSecrets" -}}
{{- $secrets := list -}}
{{- if .Values.global.imagePullSecrets -}}
{{- $secrets = concat $secrets .Values.global.imagePullSecrets -}}
{{- end -}}
{{- if .Values.image.pullSecrets -}}
{{- $secrets = concat $secrets .Values.image.pullSecrets -}}
{{- end -}}
{{- if $secrets -}}
imagePullSecrets:
{{- range $secrets }}
- name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Create environment variables
*/}}
{{- define "mcp-ballerina.env" -}}
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: SERVICE_ACCOUNT
  valueFrom:
    fieldRef:
      fieldPath: spec.serviceAccountName
- name: HOSTNAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
{{- range $key, $value := .Values.deployment.env }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}

{{/*
Create secret environment variables
*/}}
{{- define "mcp-ballerina.secretEnv" -}}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp-ballerina.secretName" . }}
      key: database-url
- name: DATABASE_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp-ballerina.secretName" . }}
      key: database-username
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp-ballerina.secretName" . }}
      key: database-password
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp-ballerina.secretName" . }}
      key: redis-url
- name: API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp-ballerina.secretName" . }}
      key: api-key
- name: JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "mcp-ballerina.secretName" . }}
      key: jwt-secret
{{- end -}}

{{/*
Create volume mounts
*/}}
{{- define "mcp-ballerina.volumeMounts" -}}
- name: config-volume
  mountPath: /config
  readOnly: true
- name: scripts-volume
  mountPath: /scripts
  readOnly: true
{{- if .Values.persistence.data.enabled }}
- name: data-volume
  mountPath: /app/data
{{- end }}
{{- if .Values.persistence.logs.enabled }}
- name: logs-volume
  mountPath: /app/logs
{{- end }}
{{- if .Values.persistence.temp.enabled }}
- name: temp-volume
  mountPath: /app/temp
{{- end }}
- name: tmp-volume
  mountPath: /tmp
- name: var-tmp-volume
  mountPath: /var/tmp
- name: run-volume
  mountPath: /run
{{- end -}}

{{/*
Create volumes
*/}}
{{- define "mcp-ballerina.volumes" -}}
- name: config-volume
  configMap:
    name: {{ include "mcp-ballerina.configMapName" . }}
    defaultMode: 0444
- name: scripts-volume
  configMap:
    name: {{ include "mcp-ballerina.scriptsConfigMapName" . }}
    defaultMode: 0555
{{- if .Values.persistence.data.enabled }}
- name: data-volume
  persistentVolumeClaim:
    claimName: {{ printf "%s-data" (include "mcp-ballerina.fullname" .) }}
{{- end }}
{{- if .Values.persistence.logs.enabled }}
- name: logs-volume
  persistentVolumeClaim:
    claimName: {{ printf "%s-logs" (include "mcp-ballerina.fullname" .) }}
{{- end }}
{{- if .Values.persistence.temp.enabled }}
- name: temp-volume
  persistentVolumeClaim:
    claimName: {{ printf "%s-temp" (include "mcp-ballerina.fullname" .) }}
{{- end }}
- name: tmp-volume
  emptyDir:
    sizeLimit: 1Gi
- name: var-tmp-volume
  emptyDir:
    sizeLimit: 1Gi
- name: run-volume
  emptyDir:
    medium: Memory
    sizeLimit: 100Mi
{{- if .Values.nginx.enabled }}
- name: nginx-config
  configMap:
    name: {{ include "mcp-ballerina.configMapName" . }}
    items:
    - key: nginx.conf
      path: nginx.conf
    defaultMode: 0444
- name: nginx-cache
  emptyDir:
    sizeLimit: 100Mi
- name: nginx-run
  emptyDir:
    medium: Memory
    sizeLimit: 50Mi
{{- end }}
{{- end -}}

{{/*
Create prometheus scraping annotations
*/}}
{{- define "mcp-ballerina.prometheusAnnotations" -}}
{{- if .Values.monitoring.serviceMonitor.enabled }}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.service.metricsPort | quote }}
prometheus.io/path: {{ .Values.monitoring.serviceMonitor.path | quote }}
{{- end }}
{{- end -}}

{{/*
Create ingress TLS configuration
*/}}
{{- define "mcp-ballerina.ingressTLS" -}}
{{- if .Values.ingress.tls }}
tls:
{{- range .Values.ingress.tls }}
- hosts:
  {{- range .hosts }}
  - {{ . | quote }}
  {{- end }}
  secretName: {{ .secretName }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Create resource requirements
*/}}
{{- define "mcp-ballerina.resources" -}}
{{- if .Values.deployment.resources }}
resources:
{{ toYaml .Values.deployment.resources | indent 2 }}
{{- end }}
{{- end -}}

{{/*
Create affinity configuration
*/}}
{{- define "mcp-ballerina.affinity" -}}
{{- if .Values.deployment.affinity }}
affinity:
{{ toYaml .Values.deployment.affinity | indent 2 }}
{{- end }}
{{- end -}}

{{/*
Create tolerations configuration
*/}}
{{- define "mcp-ballerina.tolerations" -}}
{{- if .Values.deployment.tolerations }}
tolerations:
{{ toYaml .Values.deployment.tolerations | indent 0 }}
{{- end }}
{{- end -}}

{{/*
Create node selector configuration
*/}}
{{- define "mcp-ballerina.nodeSelector" -}}
{{- if .Values.deployment.nodeSelector }}
nodeSelector:
{{ toYaml .Values.deployment.nodeSelector | indent 2 }}
{{- end }}
{{- end -}}

{{/*
Validate configuration
*/}}
{{- define "mcp-ballerina.validate" -}}
{{- include "mcp-ballerina.validateValues" . -}}
{{- end -}}