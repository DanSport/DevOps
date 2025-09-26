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
  app_revision    = "lesson-8-9"
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
