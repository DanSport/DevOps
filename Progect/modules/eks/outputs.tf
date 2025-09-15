output "cluster_name" {
  description = "Назва EKS кластера"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "URL API EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL (для IRSA)"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN OIDC провайдера (IRSA)"
  value       = try(module.eks.oidc_provider_arn, null)
}

output "cluster_security_group_id" {
  description = "Security Group control plane"
  value       = try(module.eks.cluster_security_group_id, null)
}

output "node_security_group_id" {
  description = "Security Group для нод"
  value       = try(module.eks.node_security_group_id, null)
}

output "certificate_authority_data" {
  description = "CA data для підключення (base64)"
  value       = module.eks.cluster_certificate_authority_data
}
