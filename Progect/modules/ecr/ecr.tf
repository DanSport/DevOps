data "aws_caller_identity" "current" {}

locals {
  tags = merge(
    { Name = var.ecr_name },
    var.common_tags
  )

  # Дефолтна політика: дозволити push/pull лише в межах поточного акаунта
  default_repo_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPullWithinAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages"
        ]
      }
    ]
  })

  # Дефолтна lifecycle policy:
  #  - Правило 1: видаляти untagged образи старше 14 днів
  #  - Правило 2: лишати лише 20 останніх тегованих (за push time)
  default_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = [""] # усі теги
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_repository" "this" {
  name                 = var.ecr_name
  force_delete         = var.force_delete
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.kms_key_id == null ? "AES256" : "KMS"
    kms_key         = var.kms_key_id
  }

  tags = local.tags
}

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = coalesce(var.repository_policy_json, local.default_repo_policy)
}

# resource "aws_ecr_lifecycle_policy" "this" {
#  repository = aws_ecr_repository.this.name
#  policy     = coalesce(var.lifecycle_policy_json, local.default_lifecycle_policy)
# }
