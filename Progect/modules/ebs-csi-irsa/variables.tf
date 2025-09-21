variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for naming IAM role"
  type        = string
  default     = "eks"
}
