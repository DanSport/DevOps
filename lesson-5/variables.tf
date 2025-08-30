variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1" # N. Virginia
}

# УВАГА: ім'я бакета має бути ГЛОБАЛЬНО УНІКАЛЬНИМ і тільки [a-z0-9-]
variable "tf_state_bucket_name" {
  type        = string
  description = "S3 bucket for Terraform state (must be globally unique)"
  default     = "dansport-tfstate-bogdan-20250830"
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
