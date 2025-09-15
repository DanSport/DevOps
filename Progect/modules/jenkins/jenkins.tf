locals {
  tags = merge(
    {
      "ManagedBy" = "terraform"
      "Component" = "jenkins"
    },
    var.common_tags
  )
}

# Namespace
resource "kubernetes_namespace" "ns" {
  metadata { name = var.namespace }
}

# IRSA: роль для Jenkins SA (Kaniko) з доступом до ECR
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "jenkins_irsa_role" {
  count = var.enable_irsa ? 1 : 0
  name  = "${var.cluster_name}-jenkins-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = var.oidc_provider_arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:jenkins-sa"
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "jenkins_ecr_policy" {
  count = var.enable_irsa ? 1 : 0
  name  = "${var.cluster_name}-jenkins-ecr-policy"
  role  = aws_iam_role.jenkins_irsa_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories"
        ],
        Resource = "*"
      }
    ]
  })
}

# ServiceAccount з анотацією IRSA
resource "kubernetes_service_account" "sa" {
  metadata {
    name      = "jenkins-sa"
    namespace = var.namespace
    annotations = var.enable_irsa ? {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_irsa_role[0].arn
    } : null
  }
  depends_on = [kubernetes_namespace.ns]
}

# Формування списку плагінів
locals {
  install_plugins = var.extra_plugins
}

# Helm values через templatefile
resource "helm_release" "jenkins" {
  name             = var.release_name
  namespace        = var.namespace
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = var.chart_version
  create_namespace = false
  wait             = false
  timeout          = 1200

  values = [
    templatefile("${path.module}/values.yaml", {
      service_type        = var.service_type
      service_port        = var.service_port

      persistence_enabled = var.persistence_enabled
      storage_class       = var.storage_class
      storage_size        = var.storage_size

      admin_username      = var.admin_username
      admin_password      = var.admin_password

      sa_name             = kubernetes_service_account.sa.metadata[0].name

      kaniko_image        = var.kaniko_image
      ecr_repo_uri        = var.ecr_repo_uri

      github_username     = var.github_username
      github_token        = var.github_token
      github_repo_url     = var.github_repo_url

      install_plugins     = local.install_plugins
    })
  ]

  depends_on = [
    kubernetes_service_account.sa,
    aws_iam_role_policy.jenkins_ecr_policy
  ]
}

# Виводи
output "jenkins_release_name" { value = helm_release.jenkins.name }
output "jenkins_namespace"    { value = helm_release.jenkins.namespace }
output "jenkins_service_type" { value = var.service_type }
output "jenkins_cluster_dns"  { value = "${var.release_name}.${var.namespace}.svc.cluster.local" }
output "admin_password_hint" {
  value       = var.admin_password == null ? "Пароль згенеровано чартом: kubectl -n ${var.namespace} get secret ${var.release_name} -o jsonpath={.data.jenkins-admin-password} | base64 -d" : "Пароль задано через var.admin_password"
  description = "Як отримати admin пароль"
}
