# Обов’язкові
variable "cluster_name"        { type = string }
variable "cluster_version"     { type = string } # напр. "1.29"
variable "vpc_id"              { type = string }
variable "private_subnet_ids"  { type = list(string) }
variable "public_subnet_ids"   { type = list(string) }

# Доступ до API (private endpoint корисний у VPC з VPN/DirectConnect)
variable "enable_private_endpoint" {
  description = "Увімкнути приватний доступ до API-контрол плейна"
  type        = bool
  default     = false
}

# Логи control plane
variable "cluster_log_types" {
  description = "Список типів логів control plane"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# IRSA / OIDC
variable "enable_irsa" {
  description = "Увімкнути IRSA (OIDC provider) для ServiceAccount ролей"
  type        = bool
  default     = true
}

# Ноди
variable "node_instance_types" {
  description = "Список інстанс-типів для EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Тип місткості нод: ON_DEMAND або SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "desired_size" { type = number, default = 2 }
variable "min_size"     { type = number, default = 2 }
variable "max_size"     { type = number, default = 6 }

variable "node_disk_size" {
  description = "Розмір диска для нод (ГБ)"
  type        = number
  default     = 20
}

# Додаткові теги
variable "common_tags" {
  description = "Спільні теги для всіх ресурсів EKS модуля"
  type        = map(string)
  default     = {}
}
