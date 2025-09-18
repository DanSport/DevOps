output "namespace" {
  description = "Namespace, куди встановлено Argo CD"
  value       = var.namespace
}

output "argo_cd_release_name" {
  description = "Назва релізу Argo CD"
  value       = helm_release.argo_cd.name
}

output "argo_cd_server_cluster_dns" {
  description = "Внутрішній DNS сервісу Argo CD (ClusterIP/NodePort/LB)"
  value       = "argo-cd.${var.namespace}.svc.cluster.local"
}

output "server_service_type" {
  description = "Тип сервісу Argo CD server"
  value       = var.server_service_type
}

output "admin_password_hint" {
  description = "Команда для отримання початкового admin-пароля"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d"
}
