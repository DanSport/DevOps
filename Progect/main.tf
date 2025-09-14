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

provider "aws" {
   region = var.aws_region
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

############################
# Infrastructure modules
############################

# --- VPC ---
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets

  availability_zones = var.availability_zones

  vpc_name           = "main-vpc"
}

# --- ECR ---
module "ecr" {
  source = "./modules/ecr"

  # ↓ Якщо у модулі є required vars — додай їх тут.
   ecr_name = var.ecr_name
}

# --- EKS ---
module "eks" {
  source = "./modules/eks"

  
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_version
}



# --- Jenkins через Helm ---
module "jenkins" {
  source                = "./modules/jenkins"
  namespace             = "jenkins"
  ecr_repo_uri          = module.ecr.repository_url
  aws_region            = var.region
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
}

# --- Metrics Server (для HPA) ---
module "metrics_server" {
  source    = "./modules/metrics_server"
  namespace = "kube-system"
}

# --- Argo CD через Helm + Application (GitOps) ---
module "argo_cd" {
  source         = "./modules/argo_cd"
  namespace      = "argocd"
  app_repo_url   = "https://github.com/DanSport/DevOps.git"
  app_revision   = "main"
  app_path       = "Progect/charts/django-app"  
  destination_ns = "default"
}
