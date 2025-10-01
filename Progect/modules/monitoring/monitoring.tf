resource "helm_release" "kube_prometheus_stack" {
  name             = var.release_name
  repository       = var.chart_repo_url
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 1200

  # Рендеримо values з трафарету, підкладаємо параметри
  values = [templatefile("${path.module}/values.yaml.tftpl", {
    grafana_service_type        = var.grafana_service_type
    grafana_persistence_enabled = var.grafana_persistence_enabled
    grafana_persistence_size    = var.grafana_persistence_size
    storage_class               = var.storage_class
    prometheus_retention        = var.prometheus_retention
    prometheus_pvc_size         = var.prometheus_pvc_size
  })]

  # Пароль не світимо у git
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}
