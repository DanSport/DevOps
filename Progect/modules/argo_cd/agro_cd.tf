# Namespace під Argo CD (явно, щоб можна було додати лейбли/анотації)
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
    labels = { "app.kubernetes.io/part-of" = "argocd" }
  }
}

# Встановлення Argo CD
resource "helm_release" "argo_cd" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  # values.yaml рендеримо через templatefile — підставляємо тип сервісу/порт
  values = [
    templatefile("${path.module}/values.yaml", {
      server_service_type = var.server_service_type
      server_service_port = var.server_service_port
    })
  ]

  create_namespace = false
  wait             = true
  timeout          = 600

  depends_on = [kubernetes_namespace.ns]
}

# Підготовка даних для charts/values.yaml
locals {
  # Якщо надано github_repo_url — формуємо список із одним репозиторієм, інакше порожній
  repositories = var.github_repo_url == null ? [] : [
    {
      url      = var.github_repo_url
      username = var.github_username
      password = var.github_token
    }
  ]

  repositories_yaml = yamlencode(local.repositories)
  app_value_files_yaml = yamlencode(var.app_value_files)

  repo_insecure    = var.repo_insecure
  repo_enable_lfs  = var.repo_enable_lfs
}

# Локальний чарт з Application/Repository
resource "helm_release" "argo_apps" {
  name      = "${var.name}-apps"
  chart     = "${path.module}/charts"
  namespace = var.namespace

  values = [
    templatefile("${path.module}/charts/values.yaml", {
      app_repo_url          = var.app_repo_url
      app_revision          = var.app_revision
      app_path              = var.app_path
      destination_ns        = var.destination_ns
      app_value_files_yaml  = local.app_value_files_yaml
      repositories_yaml     = local.repositories_yaml
      repo_insecure         = local.repo_insecure
      repo_enable_lfs       = local.repo_enable_lfs
    })
  ]

  wait       = true
  timeout    = 600
  depends_on = [helm_release.argo_cd]
}
