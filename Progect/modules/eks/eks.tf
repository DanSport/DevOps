module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  # ---- Cluster basics ----
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = concat(var.private_subnet_ids, var.public_subnet_ids) # control plane ENI в усіх сабнетах

  # Доступ до API
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = var.enable_private_endpoint

  # Логи control plane (зручно для дебагу та безпеки)
  cluster_enabled_log_types = var.cluster_log_types

  # IRSA (OIDC provider) – базис для ролей типу Jenkins/ArgoCD/EBS-CSI
  enable_irsa = var.enable_irsa

  # ---- Managed node groups (у приватних сабнетах) ----
  eks_managed_node_groups = {
    default = {
      subnet_ids     = var.private_subnet_ids
      instance_types = var.node_instance_types

      capacity_type = var.capacity_type # ON_DEMAND або SPOT
      min_size      = var.min_size
      max_size      = var.max_size
      desired_size  = var.desired_size

      ami_type              = "AL2023_x86_64_STANDARD"
      disk_size             = var.node_disk_size # ГБ
      labels                = { role = "general" }
      create_security_group = true
    }
  }

  # Хто створив кластер — отримає admin через aws-auth
  enable_cluster_creator_admin_permissions = true

  # ---- Addons (оновлюються автоматично до останньої сумісної) ----
  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
    # EBS CSI — для dynamic PV. Якщо потрібна окрема IRSA роль — додамо пізніше.
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
  }

  tags = merge(
    {
      "Name"      = var.cluster_name
      "ManagedBy" = "terraform"
      "Component" = "eks"
    },
    var.common_tags
  )
}
data "aws_caller_identity" "current" {}

# OIDC issuer без https:// — зручно для trust policy
locals {
  oidc_issuer_host = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer_host}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}