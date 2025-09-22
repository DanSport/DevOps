locals {
  tags = merge(
    {
      ManagedBy = "terraform"
      Component = "jenkins"
    },
    var.common_tags
  )

  # --- Умовні шматки JCasC (креденшели для seed-job) ---
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

  # --- Seed job (опційно) ---
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

  # --- Pod template для Kubernetes plugin (JCasC синтаксис плагіна, не PodSpec!) ---
  jcas_pod_template = {
    pod-template = <<YAML
      jenkins:
        clouds:
          - kubernetes:
              name: "kubernetes"
              serverUrl: "https://kubernetes.default.svc"
              namespace: "${var.namespace}"
              jenkinsUrl: "http://jenkins.${var.namespace}.svc.cluster.local:${var.service_port}"
              templates:
                - name: "default"
                  label: "default"
                  serviceAccount: "jenkins-sa"
                  containers:
                    - name: "kaniko"
                      image: "${var.kaniko_image}"
                      command: "cat"
                      ttyEnabled: true
                      ${(
                        var.ecr_repo_uri != null && var.ecr_repo_uri != ""
                      ) ? "envVars:\n                        - envVar:\n                            key: ECR_URI\n                            value: \"${var.ecr_repo_uri}\"" : ""}
                  # ВАЖЛИВО: volumes у форматі Kubernetes plugin
                  volumes:
                    - emptyDirVolume:
                        mountPath: "/kaniko/.cache"
                        memory: false
    YAML
  }

  # Фінальний набір JCasC
  jcas_configscripts = merge(local.jcas_pod_template, local.jcas_credentials, local.jcas_seed_job)
}

# -----------------------------
# Namespace
# -----------------------------
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    # якщо хочеш одразу зробити дефолтним — розкоментуй анотацію нижче
    # annotations = {
    #   "storageclass.kubernetes.io/is-default-class" = "true"
    # }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
    # за бажанням: fsType = "ext4", encrypted = "true", iops = "3000", throughput = "125"
  }
}
# -----------------------------
# IRSA для Jenkins (Kaniko → ECR)
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
# ServiceAccount (IRSA annotation)
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
    # базові дефолти з файлу (без installPlugins/JCasC/persistence!)
    file("${path.module}/values.yaml"),

    # динаміка — все важливе тут
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

        # PVC одразу на gp3 з потрібним розміром
        persistence = {
          enabled      = var.persistence_enabled
          storageClass = "gp3"
          size         = coalesce(var.storage_size, "10Gi")
        }

        # JCasC
        JCasC = {
          enabled       = true
          configScripts = local.jcas_configscripts
        }

        # Мінімальний набір плагінів БЕЗ фіксації версій (щоб уникнути конфліктів)
        installPlugins = [
          "kubernetes",
          "workflow-aggregator",
          "git",
          "configuration-as-code",
          "credentials-binding"
        ]
      }

      # Використовуємо наш SA, щоб не створювати той, що в чарті
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.sa.metadata[0].name
      }
      
    })
  ]

  depends_on = [
    kubernetes_service_account.sa
  ]
}

# -----------------------------
# RBAC на читання конфігів (щоб sidecar не падав)
# -----------------------------
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


