{{- define "pgbackrest.fullname" -}}
{{- printf "%s-pgbackrest" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "pgbackrest.labels" -}}
helm.sh/chart: pgbackrest-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: pgbackrest
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: greyeye
app.kubernetes.io/component: backup
{{- end }}
