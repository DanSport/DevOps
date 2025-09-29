# ECR
output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "ECR repository URL"
}

# EKS
output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API endpoint"
}

output "cluster_oidc_issuer_url" {
  value       = module.eks.cluster_oidc_issuer_url
  description = "OIDC issuer URL for IRSA"
}

# VPC
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

# Jenkins
output "jenkins_release" {
  value       = module.jenkins.jenkins_release_name
  description = "Helm release name for Jenkins"
}

output "jenkins_namespace" {
  value       = module.jenkins.jenkins_namespace
  description = "Namespace for Jenkins"
}

# Argo CD
output "argocd_namespace" {
  value       = module.argo_cd.namespace
  description = "Argo CD namespace"
}

output "argocd_server_dns" {
  value       = module.argo_cd.argo_cd_server_cluster_dns
  description = "Cluster DNS name of Argo CD server service"
}

output "argocd_admin_password_hint" {
  value       = module.argo_cd.admin_password_hint
  description = "How to fetch initial Argo CD admin password"
}

output "db_endpoint" {
  value = coalesce(module.rds.rds_endpoint, module.rds.aurora_endpoint)
}