variable "namespace" {
  type        = string
  description = "Namespace for Argo CD"
  default     = "argocd"
}
variable "app_repo_url" {
  type = string
}
variable "app_revision" {
  type = string
}
variable "app_path" {
  type = string
}
variable "destination_ns" {
  type = string
}
