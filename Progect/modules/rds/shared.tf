terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

###############################
# Locals & helpers
###############################
locals {
  engine_base = lower(var.engine_base) # "postgres" | "mysql"
  is_postgres = local.engine_base == "postgres"

  # Повна назва рушія залежно від Aurora/RDS
  engine_full = var.use_aurora ? (local.is_postgres ? "aurora-postgresql" : "aurora-mysql") : (local.is_postgres ? "postgres" : "mysql")

  # Надійний парсинг версії без regex: "16.3" -> "16", "8.0.35" -> "8.0"
  version_parts       = split(".", var.engine_version)
  version_major       = try(element(local.version_parts, 0), var.engine_version)
  version_major_minor = try(join(".", slice(local.version_parts, 0, 2)), var.engine_version)

  # Родини parameter group через мапи
  pg_family_map = {
    "postgres"          = "postgres${local.version_major}"
    "aurora-postgresql" = "aurora-postgresql${local.version_major}"
  }
  my_family_map = {
    "mysql"        = "mysql${local.version_major_minor}"
    "aurora-mysql" = "aurora-mysql${local.version_major_minor}"
  }

  pg_family = lookup(local.pg_family_map, local.engine_full, null)
  my_family = lookup(local.my_family_map, local.engine_full, null)

  db_port = coalesce(var.port, (local.is_postgres ? 5432 : 3306))

  common_tags = merge({ Module = "rds-universal" }, var.tags)
}

###############################
# Networking: Subnet Group + SG
###############################

resource "aws_db_subnet_group" "this" {
  name       = var.name_prefix != null ? "${var.name_prefix}-db-subnet" : "${var.name}-db-subnet"
  subnet_ids = var.subnet_ids
  tags       = merge(local.common_tags, { Name = var.name })
}

resource "aws_security_group" "this" {
  name        = var.name_prefix != null ? "${var.name_prefix}-db-sg" : "${var.name}-db-sg"
  description = "Security Group for ${var.name} database"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = var.name })

  egress {
    description      = "All egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Ingress from CIDRs
resource "aws_vpc_security_group_ingress_rule" "cidr_ingress" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = local.db_port
  to_port           = local.db_port
  description       = "DB access from ${each.value}"
}

# Ingress from other SGs (e.g., from EKS nodes)
resource "aws_vpc_security_group_ingress_rule" "sg_ingress" {
  # Ключі map відомі на plan, навіть якщо значення (SG ID) ще unknown
  for_each = var.allowed_security_group_ids_map

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = local.db_port
  to_port                      = local.db_port
  description                  = "DB access from SG ${each.key}"
}

###############################
# Parameter Groups (engine-specific)
###############################

# Postgres (RDS)
resource "aws_db_parameter_group" "pg" {
  count  = (!var.use_aurora && local.is_postgres) ? 1 : 0
  name   = var.name_prefix != null ? "${var.name_prefix}-pg-params" : "${var.name}-pg-params"
  family = local.pg_family
  tags   = local.common_tags

  parameter {
    name  = "max_connections"
    value = tostring(var.pg_max_connections)
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "log_statement"
    value = var.pg_log_statement
    apply_method = "immediate"
  }
  parameter {
    name  = "work_mem"
    value = var.pg_work_mem
    apply_method = "immediate"
  }
}

# Aurora Postgres
resource "aws_rds_cluster_parameter_group" "aurora_pg" {
  count  = (var.use_aurora && local.is_postgres) ? 1 : 0
  name   = var.name_prefix != null ? "${var.name_prefix}-apg-params" : "${var.name}-apg-params"
  family = local.pg_family
  tags   = local.common_tags

  parameter {
    name  = "max_connections"
    value = tostring(var.pg_max_connections)
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "log_statement"
    value = var.pg_log_statement
    apply_method = "immediate"
  }
  parameter {
    name  = "work_mem"
    value = var.pg_work_mem
    apply_method = "immediate"
  }
}

# MySQL (RDS)
resource "aws_db_parameter_group" "mysql" {
  count  = (!var.use_aurora && !local.is_postgres) ? 1 : 0
  name   = var.name_prefix != null ? "${var.name_prefix}-mysql-params" : "${var.name}-mysql-params"
  family = local.my_family
  tags   = local.common_tags

  parameter {
    name  = "max_connections"
    value = tostring(var.mysql_max_connections)
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "general_log"
    value = var.mysql_general_log ? "1" : "0"
    apply_method = "immediate"
  }
  parameter {
    name  = "slow_query_log"
    value = var.mysql_slow_query_log ? "1" : "0"
    apply_method = "immediate"
  }
  parameter {
    name  = "long_query_time"
    value = tostring(var.mysql_long_query_time)
    apply_method = "immediate"
  }
}

# Aurora MySQL
resource "aws_rds_cluster_parameter_group" "aurora_mysql" {
  count  = (var.use_aurora && !local.is_postgres) ? 1 : 0
  name   = var.name_prefix != null ? "${var.name_prefix}-amysql-params" : "${var.name}-amysql-params"
  family = local.my_family
  tags   = local.common_tags

  parameter {
    name  = "max_connections"
    value = tostring(var.mysql_max_connections)
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "general_log"
    value = var.mysql_general_log ? "1" : "0"
    apply_method = "immediate"
  }
  parameter {
    name  = "slow_query_log"
    value = var.mysql_slow_query_log ? "1" : "0"
    apply_method = "immediate"
  }
  parameter {
    name  = "long_query_time"
    value = tostring(var.mysql_long_query_time)
    apply_method = "immediate"
  }
}
