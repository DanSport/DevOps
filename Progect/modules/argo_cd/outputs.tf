data "kubernetes_secret" "argocd_initial" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }
  depends_on = [helm_release.argo]
}

output "argo_initial_pass_b64" {
  value     = try(data.kubernetes_secret.argocd_initial.data["password"], null)
  sensitive = true
}

output "argo_initial_pass_hint" {
  value = "Decode with: kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
