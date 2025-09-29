resource "random_password" "db" {
  count   = var.db_password == null ? 1 : 0
  length  = 20
  special = true
}

locals {
  rds_password = var.db_password != null ? var.db_password : try(random_password.db[0].result, null)
}

resource "aws_db_instance" "this" {
  count = var.use_aurora ? 0 : 1

  identifier = var.name

  engine         = local.engine_full
  engine_version = var.engine_version

  instance_class = var.instance_class

  allocated_storage     = var.storage_gb
  storage_type          = var.storage_type
  max_allocated_storage = var.max_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = local.rds_password
  port     = local.db_port

  multi_az                             = var.multi_az
  publicly_accessible                  = var.publicly_accessible
  backup_retention_period              = var.backup_retention_period
  deletion_protection                  = var.deletion_protection
  skip_final_snapshot                  = var.skip_final_snapshot
  apply_immediately                    = var.apply_immediately
  iam_database_authentication_enabled  = var.iam_database_authentication_enabled

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  parameter_group_name = local.is_postgres ? aws_db_parameter_group.pg[0].name : aws_db_parameter_group.mysql[0].name

  maintenance_window = var.maintenance_window
  backup_window      = var.backup_window

  tags = local.common_tags
}
