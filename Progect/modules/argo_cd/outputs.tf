data "kubernetes_secret" "argocd_initial" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }
}

# Виводимо base64-рядок як є (Terraform не намагається робити UTF-8)
output "argocd_admin_password_b64" {
  value     = data.kubernetes_secret.argocd_initial.data["password"]
  sensitive = true
}

# Підказка командою (звичайний string)
output "argocd_admin_password_hint" {
  value = "Decode with: kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
