locals {
  tags = merge(
    {
      ManagedBy = "terraform"
      Component = "jenkins"
    },
    var.common_tags
  )

  # --- Умовні шматки JCasC (вставляємо лише коли треба) ---
  jcas_credentials = (
    var.github_username != null && var.github_username != "" &&
    var.github_token != null && var.github_token != ""
    ) ? {
    credentials = <<YAML
      credentials:
        system:
          domainCredentials:
            - credentials:
                - usernamePassword:
                    scope: GLOBAL
                    id: github-token
                    username: "${var.github_username}"
                    password: "${var.github_token}"
                    description: "GitHub PAT for seed job"
    YAML
  } : {}

  jcas_seed_job = (
    var.github_repo_url != null && var.github_repo_url != ""
    ) ? {
    seed-job = <<YAML
      jobs:
        - script: >
            job('seed-job') {
              description('Seed job to generate pipelines')
              scm {
                git {
                  remote {
                    url('${var.github_repo_url}')
                    ${(
    var.github_username != null && var.github_username != "" &&
    var.github_token != null && var.github_token != ""
    ) ? "credentials('github-token')" : ""}
                  }
                  branches('*/main')
                }
              }
              steps {
                dsl {
                  text('''pipelineJob("goit-docker-django") {
                    definition {
                      cpsScm {
                        scriptPath("Jenkinsfile")
                        scm {
                          git {
                            remote {
                              url("${var.github_repo_url}")
                              ${(
    var.github_username != null && var.github_username != "" &&
    var.github_token != null && var.github_token != ""
) ? "credentials('github-token')" : ""}
                            }
                            branches("*/main")
                          }
                        }
                      }
                    }
                  }''')
                }
              }
            }
    YAML
} : {}

jcas_pod_template = {
  pod-template = <<YAML
      jenkins:
        clouds:
          - kubernetes:
              name: "kubernetes"
              serverUrl: "https://kubernetes.default.svc"
              namespace: "${var.namespace}"
              jenkinsUrl: "http://jenkins.${var.namespace}.svc.cluster.local:8080"
              templates:
                - name: "default"
                  label: "default"
                  serviceAccount: "jenkins-sa"
                  containers:
                    - name: "kaniko"
                      image: "${var.kaniko_image}"
                      command: ["cat"]
                      ttyEnabled: true
                      volumeMounts:
                        - name: kaniko-cache
                          mountPath: /kaniko/.cache
                      env:
                        ${(
  var.ecr_repo_uri != null && var.ecr_repo_uri != ""
) ? "- name: ECR_URI\n                          value: \"${var.ecr_repo_uri}\"" : ""}
                  volumes:
                    - name: kaniko-cache
                      emptyDir: {}
    YAML
}

# Фінальний об’єднаний набір JCasC-скриптів
jcas_configscripts = merge(local.jcas_pod_template, local.jcas_credentials, local.jcas_seed_job)

# Список плагінів, які підкладаємо в Helm
install_plugins = var.extra_plugins
}

# -----------------------------
# Namespace під Jenkins
# -----------------------------
resource "kubernetes_namespace" "ns" {
  metadata { name = var.namespace }
}

# -----------------------------
# IRSA: Роль для Jenkins SA (Kaniko) з доступом до ECR (опційно)
# -----------------------------
resource "aws_iam_role" "jenkins_irsa_role" {
  count = var.enable_irsa ? 1 : 0
  name  = "${var.cluster_name}-jenkins-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = var.oidc_provider_arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
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
    Statement = [{
      Effect = "Allow",
      Action = [
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
    }]
  })
}

# -----------------------------
# ServiceAccount для Jenkins (з IRSA-анотацією, якщо ввімкнено)
# -----------------------------
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

# -----------------------------
# Helm Release Jenkins
#   - 1-й values: статичний файл values.yaml (дефолти без шаблонів)
#   - 2-й values: динамічні налаштування та JCasC через yamlencode
# -----------------------------
resource "helm_release" "jenkins" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version

  create_namespace = false
  wait             = true
  timeout          = 1200


  values = [
    file("${path.module}/values.yaml"),

    yamlencode({
      controller = {
        admin = {
          username = var.admin_username
          password = (
            var.admin_password != null && var.admin_password != ""
          ) ? var.admin_password : ""
        }
        serviceType = var.service_type
        servicePort = var.service_port
        persistence = {
          enabled      = var.persistence_enabled
          storageClass = var.storage_class
          size         = var.storage_size
        }
        JCasC = {
          enabled       = true
          configScripts = local.jcas_configscripts
        }
      }

      # робимо явним, щоб чарт не створював свій SA
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.sa.metadata[0].name
      }

      # Список плагінів
      installPlugins = local.install_plugins
    })
  ]

  depends_on = [
    kubernetes_service_account.sa
    # aws_iam_role_policy.jenkins_ecr_policy  # НЕ додаємо індекс тут, щоб не ламалось при enable_irsa=false
  ]
}

# -----------------------------
# Outputs
# -----------------------------
output "jenkins_release_name" {
  value = helm_release.jenkins.name
}

output "jenkins_namespace" {
  value = helm_release.jenkins.namespace
}

output "jenkins_service_type" {
  value = var.service_type
}

output "jenkins_cluster_dns" {
  value = "${var.release_name}.${var.namespace}.svc.cluster.local"
}

output "admin_password_hint" {
  value       = var.admin_password == null ? "Пароль згенеровано чартом: kubectl -n ${var.namespace} get secret ${var.release_name} -o jsonpath={.data.jenkins-admin-password} | base64 -d" : "Пароль задано через var.admin_password"
  description = "Як отримати admin пароль"
}


