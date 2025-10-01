variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "monitoring"
}

variable "namespace" {
  description = "K8s namespace for Prometheus/Grafana"
  type        = string
  default     = "monitoring"
}

variable "chart_repo_url" {
  description = "Helm repo URL"
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "chart_version" {
  description = "kube-prometheus-stack chart version (optional)"
  type        = string
  default     = null
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Grafana Service type (ClusterIP|LoadBalancer|NodePort)"
  type        = string
  default     = "ClusterIP"
}

variable "grafana_persistence_enabled" {
  description = "Enable Grafana PVC"
  type        = bool
  default     = true
}

variable "grafana_persistence_size" {
  description = "Grafana PVC size"
  type        = string
  default     = "5Gi"
}

variable "storage_class" {
  description = "StorageClass for PVCs (EBS CSI)"
  type        = string
  default     = "gp3"
}

variable "prometheus_retention" {
  description = "Prometheus retention"
  type        = string
  default     = "7d"
}

variable "prometheus_pvc_size" {
  description = "Prometheus PVC size"
  type        = string
  default     = "20Gi"
}
