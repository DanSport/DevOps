variable "vpc_cidr_block" {
  description = "CIDR блок для VPC (наприклад, 10.0.0.0/16)"
  type        = string
}

variable "public_subnets" {
  description = "CIDR блоки для публічних підмереж (по одному на кожну AZ)"
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR блоки для приватних підмереж (по одному на кожну AZ)"
  type        = list(string)
}

variable "availability_zones" {
  description = "AWS Availability Zones, які будуть використані (мають відповідати кількості сабнетів)"
  type        = list(string)
}

variable "vpc_name" {
  description = "Базове ім’я для VPC та дочірніх ресурсів"
  type        = string
}

# Додаткові змінні для зручності та кастомізації

variable "common_tags" {
  description = "Додаткові теги, що додаються до всіх ресурсів"
  type        = map(string)
  default     = {}
}

variable "enable_s3_endpoint" {
  description = "Чи створювати VPC Gateway Endpoint для S3 (рекомендується, безкоштовно, економить NAT-трафік)"
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Чи створювати VPC Gateway Endpoint для DynamoDB (рекомендується, безкоштовно, економить NAT-трафік)"
  type        = bool
  default     = true
}

variable "server_service_type" {
  description = "Тип сервісу Argo CD server (ClusterIP | LoadBalancer | NodePort)"
  type        = string
  default     = "ClusterIP"
}

variable "server_service_port" {
  description = "Порт сервісу Argo CD server (актуально для LB/NodePort)"
  type        = number
  default     = 443
}
