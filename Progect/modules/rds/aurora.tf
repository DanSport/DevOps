resource "random_password" "aurora" {
  count   = var.db_password == null ? 1 : 0
  length  = 20
  special = true
}

locals {
  aurora_password = var.db_password != null ? var.db_password : try(random_password.aurora[0].result, null)
}

resource "aws_rds_cluster" "this" {
  count = var.use_aurora ? 1 : 0

  cluster_identifier = var.name

  engine         = local.engine_full
  engine_version = var.engine_version
  port           = local.db_port

  database_name   = var.db_name
  master_username = var.db_username
  master_password = local.aurora_password

  backup_retention_period              = var.backup_retention_period
  preferred_backup_window              = var.backup_window
  preferred_maintenance_window         = var.maintenance_window
  deletion_protection                  = var.deletion_protection
  apply_immediately                    = var.apply_immediately
  iam_database_authentication_enabled  = var.iam_database_authentication_enabled

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  storage_encrypted = true
  skip_final_snapshot = true

  # keep on one line to avoid parsing issues
  db_cluster_parameter_group_name = local.is_postgres ? aws_rds_cluster_parameter_group.aurora_pg[0].name : aws_rds_cluster_parameter_group.aurora_mysql[0].name

  tags = local.common_tags
}

resource "aws_rds_cluster_instance" "writer" {
  count = var.use_aurora ? 1 : 0

  identifier         = "${var.name}-writer-1"
  cluster_identifier = aws_rds_cluster.this[0].id

  instance_class = var.aurora_instance_class

  engine         = local.engine_full
  engine_version = var.engine_version
  
  publicly_accessible = var.publicly_accessible
  apply_immediately   = var.apply_immediately

  db_subnet_group_name = aws_db_subnet_group.this.name
  tags                 = local.common_tags
}
