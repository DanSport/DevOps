# Базові
variable "namespace"     { description = "Namespace для Jenkins"; type = string; default = "jenkins" }
variable "release_name"  { description = "Назва Helm релізу Jenkins"; type = string; default = "jenkins" }
variable "chart_version" { description = "Версія чарта Jenkins"; type = string; default = "5.8.27" }

# Сервіс
variable "service_type"  { description = "ClusterIP | LoadBalancer | NodePort"; type = string; default = "ClusterIP" }
variable "service_port"  { description = "Порт сервісу (для LB/NodePort)"; type = number; default = 80 }

# Зберігання
variable "persistence_enabled" { description = "Вмикати PVC для Jenkins"; type = bool; default = true }
variable "storage_class"       { description = "StorageClass для PVC"; type = string; default = "gp3" }
variable "storage_size"        { description = "Розмір PVC"; type = string; default = "10Gi" }

# Jenkins admin (для прод краще передавати секретом або залишити автогенерацію)
variable "admin_username" { description = "Admin юзер Jenkins"; type = string; default = "admin" }
variable "admin_password" { description = "Admin пароль Jenkins (небезпечно в явному вигляді)"; type = string; default = null; sensitive = true }

# IRSA / доступ до ECR без ключів
variable "cluster_name"        { description = "Назва EKS кластера (для іменування ролей)"; type = string }
variable "oidc_provider_arn"   { description = "ARN OIDC провайдера (з EKS модуля)"; type = string }
variable "oidc_provider_url"   { description = "URL OIDC провайдера (з EKS модуля)"; type = string }
variable "enable_irsa"         { description = "Увімкнути IRSA для Jenkins SA"; type = bool; default = true }

# ECR (для зручності підказок/лейблів; Kaniko з IRSA працює і без явного URI)
variable "ecr_repo_uri"        { description = "ECR repo URI (необов'язково)"; type = string; default = null }

# JCasC / Kaniko опції
variable "kaniko_image"        { description = "Образ Kaniko executor"; type = string; default = "gcr.io/kaniko-project/executor:latest" }
variable "extra_plugins" {
  description = "Додаткові Jenkins плагіни (name[:version])"
  type        = list(string)
  default     = [
    "kubernetes:4267.v6be2eb2f5d2a",
    "workflow-aggregator:596.v8c21c963d92d",
    "credentials:1319.v7eb_51b_3a_c97b_",
    "configuration-as-code:1775.v810dc950b_514",
    "git:5.6.0",
    "ssh-credentials:332.va_1f15c56da_1c",
    "matrix-auth:3.2.2",
    "workflow-job:1385.vb_58b_86ea_fff1",
    "timestamper:1.27",
    "ansiColor:1.0.4",
    "pipeline-stage-view:2.34"
  ]
}

# (опційно) Git креденшели для seed job (через JCasC)
variable "github_username" { description = "GitHub username для seed job"; type = string; default = null; sensitive = true }
variable "github_token"    { description = "GitHub PAT для seed job"; type = string; default = null; sensitive = true }
variable "github_repo_url" { description = "Git URL для seed job"; type = string; default = null }

# Теги
variable "common_tags" { description = "Додаткові теги"; type = map(string); default = {} }
