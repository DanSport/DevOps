variable "namespace" {
  type        = string
  description = "Namespace to install metrics-server"
  default     = "kube-system"
}
