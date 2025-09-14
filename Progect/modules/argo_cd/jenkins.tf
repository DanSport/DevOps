resource "kubernetes_namespace" "ns" {
  metadata { name = var.namespace }
}

resource "helm_release" "argo" {
  name       = "argo-cd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.12"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    installCRDs = true
    server = {
      service = { type = "ClusterIP" }
    }
  })]

  depends_on = [kubernetes_namespace.ns]
}

# Замість kubernetes_manifest — встановлюємо Application через офіційний чарт "argocd-apps"
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "1.6.2"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    applications = [
      {
        name      = "django-app"
        namespace = var.namespace
        project   = "default"
        source = {
          repoURL        = var.app_repo_url
          targetRevision = var.app_revision
          path           = var.app_path
          helm           = {}
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.destination_ns
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          syncOptions = ["CreateNamespace=true"]
        }
      }
    ]
  })]

  depends_on = [helm_release.argo]
}
