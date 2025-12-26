{{- define "apache-guacamole.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "apache-guacamole.fullname" -}}
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

{{- define "apache-guacamole.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "apache-guacamole.labels" -}}
helm.sh/chart: {{ include "apache-guacamole.chart" . }}
{{ include "apache-guacamole.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "apache-guacamole.selectorLabels" -}}
app.kubernetes.io/name: {{ include "apache-guacamole.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "apache-guacamole.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- include "apache-guacamole.fullname" . }}
{{- else }}
{{- default "default" "" }}
{{- end }}
{{- end }}

{{- define "apache-guacamole.guacamole.fullname" -}}
{{ .Release.Name }}-guacamole
{{- end }}

{{- define "apache-guacamole.guacd.fullname" -}}
{{ .Release.Name }}-guacd
{{- end }}

{{- define "apache-guacamole.mariadb.fullname" -}}
{{ .Release.Name }}-mariadb
{{- end }}

{{- define "apache-guacamole.hpa.apiVersion" -}}
{{- if semverCompare ">=1.23-0" .Capabilities.KubeVersion.GitVersion }}
autoscaling/v2
{{- else }}
autoscaling/v2beta2
{{- end }}
{{- end }}
