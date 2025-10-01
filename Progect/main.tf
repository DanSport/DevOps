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

# ---------------- Providers ----------------
provider "aws" {
  region = var.aws_region
}

# ВАЖЛИВО: використовуємо виходи твого EKS-модуля (wrapper) — в ньому вже є:
# - module.eks.cluster_name
# - module.eks.cluster_endpoint
# - module.eks.certificate_authority_data
# (див. Progect/modules/eks/outputs.tf у твоєму дампі) :contentReference[oaicite:0]{index=0}

# ---- Kubernetes providers: DEFAULT і ALIAS=eks (дзеркальні) ----
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# ---- Helm providers: DEFAULT і ALIAS=eks (дзеркальні) ----
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "helm" {
  alias = "eks"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# ---------------- VPC ----------------
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
  vpc_name           = "main-vpc"
}

# ---------------- ECR ----------------
module "ecr" {
  source = "./modules/ecr"

  ecr_name             = var.ecr_name
  scan_on_push         = true
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
}

# ---------------- EKS ----------------
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}

# ---------------- Argo CD ----------------
module "argo_cd" {
  source = "./modules/argo_cd"

  name                = "argo-cd"
  namespace           = "argocd"
  chart_version       = "6.7.12"
  server_service_type = "ClusterIP"
  server_service_port = 443

  # GitOps application
  app_repo_url    = "https://github.com/DanSport/DevOps.git"
  app_revision    = "main"
  app_path        = "Progect/charts/django-app"
  destination_ns  = "default"
  app_value_files = []

  # (опційно) приватний репозиторій у Argo CD
  github_username = null
  github_token    = null
  github_repo_url = null

  # ЯВНО пробросимо alias-провайдери у модуль
  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  # Щоб helm/k8s пішли тільки після створення кластера
  depends_on = [module.eks]
}

# ---------------- Jenkins ----------------
module "jenkins" {
  source = "./modules/jenkins"

  namespace    = "jenkins"
  release_name = "jenkins"

  service_type = "ClusterIP"
  service_port = 80

  persistence_enabled = true
  storage_class       = "gp3"
  storage_size        = "10Gi"

  admin_username = "admin"

  # IRSA/OIDC із EKS
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url
  enable_irsa       = true

  # ECR для Kaniko/Jenkins
  ecr_repo_uri = module.ecr.repository_url

  github_username = null
  github_token    = null
  github_repo_url = null
  gitops_ssh_private_key = var.gitops_ssh_private_key

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
    aws        = aws
  }

  depends_on = [module.eks, module.ecr]
}

module "rds" {
  source = "./modules/rds"

  name           = var.db_name_prefix
  use_aurora     = var.db_use_aurora
  engine_base    = var.db_engine_base       # "postgres" або "mysql"
  engine_version = var.db_engine_version    # напр. "16.3" або "8.0.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # Дозволити доступ з іншого SG (наприклад, EKS ноди). Можеш забрати, якщо не треба.
  allowed_security_group_ids_map = {
  eks_nodes = module.eks.node_security_group_id
  }

  # Облікові дані (пароль можна лишити null — згенерується)
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # RDS-only
  instance_class          = var.db_instance_class
  storage_gb              = var.db_storage_gb
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention

  # Aurora-only
  aurora_instance_class = var.db_aurora_instance_class

  # Безпека
  deletion_protection = var.db_deletion_protection
  publicly_accessible = false

  tags = { Project = "lesson-db-module" }
}

module "monitoring" {
  source = "./modules/monitoring"

  release_name               = "monitoring"
  namespace                  = "monitoring"
  grafana_admin_password     = var.grafana_admin_password

  # Можеш змінювати за потреби
  grafana_service_type       = "ClusterIP"
  storage_class              = "gp3"
  grafana_persistence_size   = "5Gi"
  prometheus_retention       = "7d"
  prometheus_pvc_size        = "20Gi"

  # Можна зафіксувати версію чарту:
  # chart_version = "XX.YY.Z"
}
