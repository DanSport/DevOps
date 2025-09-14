output "ecr_repository_url" { value = module.ecr.repository_url }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_oidc_issuer" { value = module.eks.oidc_issuer }
output "vpc_id" { value = module.vpc.vpc_id }
output "jenkins_admin_pass" { value = module.jenkins.admin_password }
output "argo_initial_pass_b64" {
  value       = module.argo_cd.argocd_admin_password_b64
  sensitive   = true
  description = "Argo CD initial admin password in base64 (use the hint to decode)."
}

output "argo_initial_pass_hint" {
  value = "Decode with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}