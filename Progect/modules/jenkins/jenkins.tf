resource "kubernetes_namespace" "ns" {
  metadata { name = var.namespace }
}

resource "kubernetes_secret" "aws" {
  metadata {
    name      = "jenkins-aws"
    namespace = var.namespace
  }

  data = {
    AWS_REGION            = var.aws_region
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
  }

  type       = "Opaque"
  depends_on = [kubernetes_namespace.ns]
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = var.namespace
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "5.5.15"

  create_namespace = false

  values = [file("${path.module}/values.yaml")]

  wait    = false
  timeout = 1200

  depends_on = [kubernetes_secret.aws]
}

# Виводи
output "admin_password" {
  value = "changeme123" # якщо залишиш як у values.yaml
}
