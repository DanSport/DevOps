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
  region  = var.region
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

# --- інші твої модулі (s3-backend, vpc, ecr, eks) ---

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
  app_path       = "charts/django-app"   # ← виправлено
  destination_ns = "default"
}
