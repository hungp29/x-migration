{{/*
Expand the chart name.
*/}}
{{- define "db-migration.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a fully-qualified app name, capped at 63 characters.
*/}}
{{- define "db-migration.fullname" -}}
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
Common labels applied to every resource.
*/}}
{{- define "db-migration.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "db-migration.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used in matchLabels so they must be stable across upgrades.
*/}}
{{- define "db-migration.selectorLabels" -}}
app.kubernetes.io/name: {{ include "db-migration.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "db-migration.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "db-migration.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Flyway JDBC URL assembled from the postgresql values block.
*/}}
{{- define "db-migration.jdbcUrl" -}}
{{- printf "jdbc:postgresql://%s:%d/%s" .Values.postgresql.host (int .Values.postgresql.port) .Values.postgresql.database }}
{{- end }}
