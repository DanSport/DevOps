output "repository_url" {
  description = "URL репозиторію ECR"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN репозиторію ECR"
  value       = aws_ecr_repository.this.arn
}

output "registry_id" {
  description = "ID реєстру ECR"
  value       = aws_ecr_repository.this.registry_id
}

output "repository_name" {
  description = "Назва репозиторію"
  value       = aws_ecr_repository.this.name
}
