# Обов'язкові
variable "ecr_name" {
  description = "Назва ECR репозиторію"
  type        = string
}

# Функціональні перемикачі
variable "scan_on_push" {
  description = "Сканувати образи під час пушу (ECR image scanning)"
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "IMMUTABLE (реком.) або MUTABLE. IMMUTABLE забороняє перезапис існуючих тегів"
  type        = string
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "force_delete" {
  description = "Видаляти репозиторій разом з усіма образами (для dev=true, для prod=false)"
  type        = bool
  default     = true
}

# Шифрування
variable "kms_key_id" {
  description = "ARN/ID KMS-ключа для шифрування образів. Якщо null — AES256."
  type        = string
  default     = null
}

# Політика доступу (JSON)
variable "repository_policy_json" {
  description = "JSON-політика репозиторію. Якщо null — використати дефолт (доступ лише в межах акаунта)"
  type        = string
  default     = null
}

# Lifecycle policy (JSON)
variable "lifecycle_policy_json" {
  description = "JSON lifecycle policy. Якщо null — застосуємо дефолт (чистити untagged > 14д і зберігати лише 20 останніх тегованих)"
  type        = string
  default     = null
}

# Додаткові теги
variable "common_tags" {
  description = "Додаткові теги, які застосовуються до всіх ресурсів модуля"
  type        = map(string)
  default     = {}
}
