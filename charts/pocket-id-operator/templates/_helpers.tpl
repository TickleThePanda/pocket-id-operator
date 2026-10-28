{{/*
Chart name based on project name.
Truncated to 63 characters for Kubernetes compatibility.
*/}}
{{- define "chart.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name of the chart (with release name prefix).
Combines release name with chart name.
Truncated to 63 characters for Kubernetes compatibility.
*/}}
{{- define "chart.fullname" -}}
{{- $name := include "chart.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Namespace for generated references.
Always uses the Helm release namespace.
*/}}
{{- define "chart.namespaceName" -}}
{{ .Release.Namespace }}
{{- end }}



{{/*
Service name with proper truncation for Kubernetes 63-character limit.
Takes a context with .suffix for the service type (e.g., "webhook-service").
If fullname + suffix exceeds 63 chars, truncates fullname to 45 chars.
*/}}
{{- define "chart.serviceName" -}}
{{- $fullname := include "chart.fullname" .context -}}
{{- if gt (len $fullname) 45 -}}
{{- printf "%s-%s" (trunc 45 $fullname | trimSuffix "-") .suffix | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $fullname .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for Helm charts.
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for matching pods and services.
Only includes name and instance for consistent selection.
*/}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
The operator's RBAC rules: files/manager-rules.yaml, generated from the
kubebuilder markers, minus the workload kinds when operator.manageWorkloads is
false.
*/}}
{{- define "pocket-id-operator.managerRules" -}}
{{- $workloads := dict "apps" (list "deployments" "statefulsets") "" (list "services" "persistentvolumeclaims") "gateway.networking.k8s.io" (list "httproutes") }}
{{- $rules := list }}
{{- range .Files.Get "files/manager-rules.yaml" | fromYamlArray }}
{{- $rule := . }}
{{- if not $.Values.operator.manageWorkloads }}
{{- $drop := list }}
{{- range $rule.apiGroups }}
{{- $drop = concat $drop (get $workloads . | default list) }}
{{- end }}
{{- $kept := list }}
{{- range $rule.resources }}
{{- if not (has . $drop) }}
{{- $kept = append $kept . }}
{{- end }}
{{- end }}
{{- $rule = set $rule "resources" $kept }}
{{- end }}
{{- if $rule.resources }}
{{- $rules = append $rules $rule }}
{{- end }}
{{- end }}
{{- toYaml $rules }}
{{- end }}
