resource "helm_release" "kube_prometheus_stack" {
  name             = var.release_name
  repository       = var.chart_repo_url
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 1200

  # читаємо звичайний values.yaml
  values = [file("${path.module}/values.yaml")]

  # пароль краще не класти в git — передаємо чутливо
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # нижче — опційні оверрайди, якщо не зашиті у values.yaml
  set {
    name  = "grafana.service.type"
    value = var.grafana_service_type              # "ClusterIP" | "LoadBalancer" | "NodePort"
  }
  set {
    name  = "grafana.persistence.enabled"
    value = var.grafana_persistence_enabled ? "true" : "false"
  }
  set {
    name  = "grafana.persistence.size"
    value = var.grafana_persistence_size          # "5Gi" тощо
  }
  set {
    name  = "grafana.persistence.storageClassName"
    value = var.storage_class                     # "gp3" тощо
  }
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention              # "7d" тощо
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.storage_class
  }
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_pvc_size               # "20Gi" тощо
  }
}
