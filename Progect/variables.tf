variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "tf_state_bucket_name" {
  type    = string
  default = "dansport-tfstate-bogdan-20250903"
}

variable "tf_lock_table_name" {
  type    = string
  default = "terraform-locks"
}

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

variable "ecr_name" {
  type    = string
  default = "lesson-7-ecr"
}

variable "eks_cluster_name" {
  type    = string
  default = "lesson-7-eks"
}

variable "eks_version" {
  type    = string
  default = "1.30"
}

variable "aws_access_key_id" {
  type      = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type      = string
  sensitive = true
}
variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}