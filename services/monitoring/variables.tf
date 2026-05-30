variable "release_name" {
  type        = string
  description = "Helm release name"
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  type        = string
  description = "Chart version"
  default     = "54.0.0"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace"
  default     = "monitoring"
}

variable "prometheus_retention" {
  type        = string
  description = "Prometheus data retention period"
  default     = "30d"
}

variable "prometheus_storage_size" {
  type        = string
  description = "Prometheus storage size"
  default     = "50Gi"
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
}

variable "enable_ingress" {
  type        = bool
  description = "Enable Grafana ingress"
  default     = false
}

variable "grafana_hosts" {
  type        = list(string)
  description = "Grafana ingress hosts"
  default     = []
}
