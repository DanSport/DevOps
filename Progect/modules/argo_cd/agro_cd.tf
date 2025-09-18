# Namespace під Argo CD (щоб можна було додати лейбли/анотації)
resource "kubernetes_namespace" "ns" {
  metadata {
    name   = var.namespace
    labels = { "app.kubernetes.io/part-of" = "argocd" }
  }
}

# Встановлення Argo CD з офіційного чарта
resource "helm_release" "argo_cd" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  values = [
    file("${path.module}/values.yaml")
  ]

  depends_on = [kubernetes_namespace.ns]
}

# ----- Дані для values локального шаблону (який віддаємо в argocd-apps) -----
locals {
  # Якщо задано приватний репозиторій — реєструємо його в Argo CD (Secret)
  repositories = var.github_repo_url == null ? [] : [
    {
      url      = var.github_repo_url
      username = var.github_username
      password = var.github_token
    }
  ]

  repositories_yaml    = yamlencode(local.repositories)
  app_value_files_yaml = yamlencode(var.app_value_files)

  # Ніяких null у шаблон — тільки bool
  repo_insecure   = coalesce(var.repo_insecure, false)
  repo_enable_lfs = coalesce(var.repo_enable_lfs, false)
}

# ОГОЛОШУЄМО Argo CD Applications/Repositories через офіційний чарт argocd-apps
resource "helm_release" "argo_apps" {
  name       = "${var.name}-apps"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "1.6.2"

  values = [
    templatefile("${path.module}/charts/values.yaml", {
      app_repo_url = var.app_repo_url
      app_revision = var.app_revision
      # ВАЖЛИВО: шлях від КОРЕНЯ репозиторію (у тебе це саме "charts/django-app")
      app_path             = var.app_path
      destination_ns       = var.destination_ns
      app_value_files_yaml = local.app_value_files_yaml
      repositories_yaml    = local.repositories_yaml
      repo_insecure        = local.repo_insecure
      repo_enable_lfs      = local.repo_enable_lfs
    })
  ]

  wait       = true
  timeout    = 600
  depends_on = [helm_release.argo_cd]
}
