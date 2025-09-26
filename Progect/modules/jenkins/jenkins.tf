############################
# JCasC scripts (host key + job DSL)
############################
locals {
  jcas_configscripts = {
    jobs = <<-YAML
      jobs:
        - script: >
            pipelineJob('django-app-ci') {
              description('CI/CD for Django app: build & push to ECR, bump Helm values, push to repo')
              definition {
                cpsScm {
                  scm {
                    git {
                      remote('https://github.com/DanSport/DevOps.git')   // checkout по HTTPS можемо поставити нижче, якщо треба
                      credentials('gitops-ssh')
                      branch('*/lesson-8-9')
                    }
                  }
                  scriptPath('Progect/Jenkinsfile')
                }
              }
              triggers { scm('H/2 * * * *') }
            }
    YAML
  }
}

############################
# Namespace
############################
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}

############################
# StorageClass (gp3)
############################
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    # annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
  }
}

############################
# IRSA: IAM role + policy for Jenkins SA (Kaniko → ECR)
############################
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

############################
# ServiceAccount (IRSA annotation)
############################
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

############################
# SSH key as k8s Secret → auto-credential in Jenkins
############################
resource "kubernetes_secret" "gitops_ssh" {
  metadata {
    name      = "gitops-ssh"
    namespace = var.namespace
    labels = {
      "jenkins.io/credentials-type" = "sshUserPrivateKey"
    }
    annotations = {
      "jenkins.io/credentials-description" = "GitHub deploy key for GitOps push"
      "jenkins.io/credentials-username"    = "git"
      "jenkins.io/credentials-id"          = "gitops-ssh"
    }
  }

  type = "kubernetes.io/ssh-auth"

  # ВАЖЛИВО: провайдер сам base64-енкодить – даємо сирий ключ
  data = {
    "ssh-privatekey" = var.gitops_ssh_private_key
  }
}

############################
# Jenkins via Helm (JCasC увімкнено + потрібні плагіни + ресурси/проби)
############################
resource "helm_release" "jenkins" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version

  create_namespace = false
  wait             = false
  timeout          = 600
  max_history      = 3

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
          storageClass = "gp3"
          size         = coalesce(var.storage_size, "10Gi")
        }

        # Ресурси/опції JVM та проби — стабільний перший старт
        resources = {
          requests = { cpu = "500m", memory = "1Gi" }
          limits   = { cpu = "2",    memory = "2Gi" }
        }
        javaOpts = "-Djenkins.install.runSetupWizard=false -Xms512m -Xmx1024m"

        startupProbe = {
          httpGet = { path = "/login", port = "http" }
          failureThreshold = 60
          periodSeconds    = 5
          timeoutSeconds   = 1
        }
        livenessProbe = {
          httpGet = { path = "/login", port = "http" }
          initialDelaySeconds = 120
          periodSeconds       = 10
          failureThreshold    = 12
        }
        readinessProbe = {
          httpGet = { path = "/login", port = "http" }
          initialDelaySeconds = 60
          periodSeconds       = 5
          failureThreshold    = 12
        }

        # JCasC: автоконфіг (host key strategy + job DSL)
        JCasC = {
          enabled       = true
          configScripts = local.jcas_configscripts
        }

        # Плагіни: Git, DSL, CasC, k8s credentials provider
        installPlugins = [
          "workflow-aggregator",
          "git",
          "git-client",
          "ssh-credentials",
          "credentials-binding",
          "kubernetes",
          "kubernetes-credentials-provider",
          "configuration-as-code",
          "job-dsl"
        ]
      }

      # Використовуємо наш SA (із IRSA), чарт свій не створює
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.sa.metadata[0].name
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.ns,
    kubernetes_service_account.sa,
    kubernetes_secret.gitops_ssh
  ]
}

############################
# RBAC (опційно, на читання конфігів)
############################
resource "kubernetes_role" "jenkins_config_reader" {
  metadata {
    name      = "jenkins-config-reader"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [helm_release.jenkins]
}

resource "kubernetes_role_binding" "jenkins_config_reader_binding" {
  metadata {
    name      = "jenkins-config-reader-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_config_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.sa.metadata[0].name
    namespace = var.namespace
  }

  depends_on = [kubernetes_role.jenkins_config_reader]
}

############################
# Outputs
############################
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
