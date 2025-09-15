terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

############################################
# Providers
############################################

variable "aws_region" {
  description = "AWS region (наприклад, us-east-1)"
  type        = string
}

provider "aws" {
  region = var.aws_region
}

############################################
# Network / EKS prerequisites
############################################

# --- VPC ---
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones

  vpc_name = "main-vpc"
}

# --- ECR ---
module "ecr" {
  source  = "./modules/ecr"
  ecr_name = var.ecr_name
  # Якщо ваш модуль підтримує: scan_on_push = true
}

# --- EKS (використовуємо приватні сабнети для нод) ---
module "eks" {
  source = "./modules/eks"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_version
}

############################################
# Підключення до кластера без kubeconfig
############################################

data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

############################################
# Platform add-ons через Helm / GitOps
############################################

module "jenkins" {
  source = "./modules/jenkins"

  namespace      = "jenkins"
  release_name   = "jenkins"
  chart_version  = "5.8.27"
  service_type   = "ClusterIP" # або "LoadBalancer"
  storage_class  = "gp3"
  storage_size   = "10Gi"

  cluster_name       = module.eks.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url
  enable_irsa        = true

  ecr_repo_uri    = module.ecr.repository_url

  # опційно:
  # admin_password = "changeme123"
  # github_username = var.github_username
  # github_token    = var.github_token
  # github_repo_url = var.github_repo_url

  providers = { aws = aws, helm = helm, kubernetes = kubernetes }
}

# --- Metrics Server (для HPA) ---
module "metrics_server" {
  source    = "./modules/metrics_server"
  namespace = "kube-system"
}

# --- Argo CD + ваша GitOps-аплікація ---
module "argo_cd" {
  source = "./modules/argo_cd"

  name                = "argo-cd"
  namespace           = "argocd"
  chart_version       = "6.7.12"
  server_service_type = "ClusterIP" # або "LoadBalancer"

  app_repo_url   = var.app_repo_url
  app_revision   = "main"
  app_path       = "Progect/charts/django-app"
  destination_ns = "default"
  app_value_files = [] # напр., ["values-prod.yaml"]

  # опційно, якщо реєструєш приватний репозиторій
  github_username = null
  github_token    = null
  github_repo_url = null

  providers = { helm = helm, kubernetes = kubernetes }
}


############################################
# Variables (оголошення очікуваних змінних)
############################################

variable "vpc_cidr_block" {
  description = "CIDR для VPC"
  type        = string
}

variable "public_subnets" {
  description = "Список публічних підмереж"
  type        = list(string)
}

variable "private_subnets" {
  description = "Список приватних підмереж"
  type        = list(string)
}

variable "availability_zones" {
  description = "Список AZ (наприклад, [\"us-east-1a\",\"us-east-1b\",\"us-east-1c\"])"
  type        = list(string)
}

variable "ecr_name" {
  description = "Назва ECR репозиторію"
  type        = string
}

variable "eks_cluster_name" {
  description = "Назва кластера EKS"
  type        = string
}

variable "eks_version" {
  description = "Версія Kubernetes для EKS (наприклад, \"1.29\")"
  type        = string
}

variable "app_repo_url" {
  description = "Git URL репозиторію з маніфестами/чартами для Argo CD"
  type        = string
}

############################################
# (Необов'язково) базові outputs
############################################

output "region" {
  value = var.aws_region
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
