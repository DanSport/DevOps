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

# Після створення EKS будемо користуватись kubeconfig
provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
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
  app_path        = "charts/django-app"
  destination_ns  = "default"
  app_value_files = []

  # (опціонально) реєстрація приватного репозиторію в Argo CD
  github_username = null
  github_token    = null
  github_repo_url = null

  # Після створення кластера (щоб kubeconfig вже був оновлений)
  depends_on = [module.eks]
}

# ---------------- Jenkins ----------------
module "jenkins" {
  source = "./modules/jenkins"

  namespace     = "jenkins"
  release_name  = "jenkins"
  chart_version = "5.8.27"

  service_type = "ClusterIP" # або "LoadBalancer"
  service_port = 80

  persistence_enabled = true
  storage_class       = "gp3"
  storage_size        = "10Gi"

  admin_username = "admin"
  # admin_password = null  # дозволь чарту згенерувати секрет

  # IRSA/OIDC з EKS модуля
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url
  enable_irsa       = true

  # Підказка для Kaniko/Jenkins (URI ECR)
  ecr_repo_uri = module.ecr.repository_url

  # (опційно) seed job креденшели
  github_username = null
  github_token    = null
  github_repo_url = null

  depends_on = [module.eks, module.ecr]
}
