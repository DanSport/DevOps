output "ecr_repository_url" { value = module.ecr.repository_url }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_oidc_issuer" { value = module.eks.oidc_issuer }
output "vpc_id" { value = module.vpc.vpc_id }
