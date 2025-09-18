terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.29" }
    helm       = { source = "hashicorp/helm", version = "~> 2.12" }
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
