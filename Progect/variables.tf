# Єдиний регіон
variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

# (опційно) backend для TF state — якщо використовуєш
variable "tf_state_bucket_name" {
  type        = string
  description = "S3 bucket for Terraform state (optional)"
  default     = "dansport-tfstate-bogdan-20250903"
}

variable "tf_lock_table_name" {
  type        = string
  description = "DynamoDB table for state locking (optional)"
  default     = "terraform-locks"
}

# VPC
variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "private_subnets" {
  type    = list(string)
  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ECR
variable "ecr_name" {
  type    = string
  default = "lesson-7-ecr"
}

# EKS
variable "eks_cluster_name" {
  type    = string
  default = "lesson-7-eks"
}
variable "eks_version" {
  type        = string
  description = "Kubernetes version for EKS (e.g., 1.29). Переконайся, що підтримується в AWS."
  default     = "1.29"
}

# Jenkins / GitOps (за потреби)
variable "github_username" {
  type      = string
  sensitive = true
  default   = null
}
variable "github_token" {
  type      = string
  sensitive = true
  default   = null
}
variable "github_repo_url" {
  type    = string
  default = null
}

variable "gitops_ssh_private_key" {
  description = "Private SSH key for Git push (OpenSSH format)"
  type        = string
  sensitive   = true
}
variable "db_use_aurora" {
  type    = bool
  default = false
}

variable "db_engine_base" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "16.3"
}

variable "db_name_prefix" {
  type    = string
  default = "app-db"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "db_storage_gb" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention" {
  type    = number
  default = 7
}

variable "db_aurora_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "grafana_admin_password" {
  description = "Пароль admin для Grafana"
  type        = string
  sensitive   = true
}
