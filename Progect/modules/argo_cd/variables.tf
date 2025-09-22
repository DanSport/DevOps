variable "name" {
  description = "Назва Helm-релізу Argo CD"
  type        = string
  default     = "argo-cd"
}

variable "namespace" {
  description = "Namespace для Argo CD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Версія чарта argo-cd"
  type        = string
  default     = "8.5.4"
}

variable "server_service_type" {
  description = "Тип сервісу Argo CD server (ClusterIP | LoadBalancer | NodePort)"
  type        = string
  default     = "ClusterIP"
}

variable "server_service_port" {
  description = "Порт сервісу Argo CD server"
  type        = number
  default     = 443
}

variable "app_repo_url" {
  description = "Git URL репозиторію з маніфестами/чартами"
  type        = string
}

variable "app_revision" {
  description = "Гілка/тег застосунку"
  type        = string
  default     = "main"
}

variable "app_path" {
  description = "Шлях у репозиторії до чарту/маніфестів"
  type        = string
  default     = "Progect/charts/django-app"
}

variable "destination_ns" {
  description = "Namespace, куди деплоїться апка"
  type        = string
  default     = "default"
}

variable "app_value_files" {
  description = "Список шляхів до values-файлів у репозиторії апки (відносно app_path)"
  type        = list(string)
  default     = []
}

variable "github_username" {
  description = "Git username"
  type        = string
  default     = null
  sensitive   = true
}

variable "github_token" {
  description = "Git token/PAT"
  type        = string
  default     = null
  sensitive   = true
}

variable "github_repo_url" {
  description = "Git repo URL (для реєстрації в Argo CD)"
  type        = string
  default     = null
}

variable "repo_insecure" {
  description = "Дозволити insecure для репозиторію"
  type        = bool
  default     = null
}

variable "repo_enable_lfs" {
  description = "Увімкнути Git LFS"
  type        = bool
  default     = null
}
