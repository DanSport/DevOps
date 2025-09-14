resource "kubernetes_namespace" "ns" {
  metadata { name = var.namespace }
}

resource "helm_release" "argo" {
  name       = "argo-cd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.6.12"
  values     = [file("${path.module}/values.yaml")]
}

# Application (GitOps)
resource "kubernetes_manifest" "app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "django-app"
      namespace = var.namespace
      labels    = { app = "django-app" }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.app_repo_url
        targetRevision = var.app_revision
        path           = var.app_path
        helm           = { releaseName = "django-app" }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_ns
      }
      syncPolicy = {
        automated = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [helm_release.argo]
}
