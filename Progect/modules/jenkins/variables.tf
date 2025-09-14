variable "namespace" {
  type        = string
  default     = "jenkins"
  description = "Kubernetes namespace for Jenkins"
}

variable "ecr_repo_uri" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_access_key_id" {
  type      = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type      = string
  sensitive = true
}
