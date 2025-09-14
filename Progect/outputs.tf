# ECR
output "ecr_repository_url" {
  value = module.ecr.repository_url
}

# EKS
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer" {
  value = module.eks.oidc_issuer
}

# VPC
output "vpc_id" {
  value = module.vpc.vpc_id
}

# Jenkins
output "jenkins_admin_pass" {
  value     = "changeme123"  # якщо ти виносив у секрет/var — заміни відповідно
  sensitive = true
}

# Argo CD
output "argo_initial_pass_b64" {
  value     = module.argo_cd.argo_initial_pass_b64
  sensitive = true
}

output "argo_initial_pass_hint" {
  value = module.argo_cd.argo_initial_pass_hint
}
