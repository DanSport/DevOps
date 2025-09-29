###############################
# Inputs
###############################

variable "name" {
  description = "Base name for DB resources"
  type        = string
}

variable "name_prefix" {
  description = "Optional name prefix (overrides default naming)"
  type        = string
  default     = null
}

variable "use_aurora" {
  description = "If true → create Aurora cluster, otherwise a single RDS instance"
  type        = bool
  default     = false
}

variable "engine_base" {
  description = "Base engine family: postgres | mysql"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Engine version, e.g. 16.3 for Postgres or 8.0.35 for MySQL/Aurora MySQL"
  type        = string
}

variable "port" {
  description = "Database port; defaults to 5432 for Postgres, 3306 for MySQL"
  type        = number
  default     = null
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master/user name"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Master/user password (if null, random will be generated)"
  type        = string
  default     = null
  sensitive   = true
}

variable "instance_class" {
  description = "Instance class for standard RDS (e.g., db.t4g.small)"
  type        = string
  default     = "db.t4g.small"
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora instances (e.g., db.r6g.large)"
  type        = string
  default     = "db.r6g.large"
}

variable "storage_gb" {
  description = "Allocated storage (RDS only)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max autoscaling storage for RDS (0 to disable)"
  type        = number
  default     = 0
}

variable "storage_type" {
  description = "Storage type (gp3, gp2, io1, etc.) for RDS"
  type        = string
  default     = "gp3"
}

variable "multi_az" {
  description = "Create a Multi-AZ RDS instance (ignored for Aurora)"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "If true, the instance/cluster is publicly accessible"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (RDS); for Aurora handled via deletion_protection/backups"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately (may cause downtime)"
  type        = bool
  default     = true
}

variable "maintenance_window" {
  description = "Preferred maintenance window (e.g., Sun:23:00-Mon:01:30)"
  type        = string
  default     = null
}

variable "backup_window" {
  description = "Preferred backup window (e.g., 02:00-03:00)"
  type        = string
  default     = null
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM authentication"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID where to place the DB"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (2+ subnets across AZs recommended)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the DB port"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security Group IDs allowed to access the DB port (e.g., EKS node group SG)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

################################
# Postgres tuning vars
################################
variable "pg_max_connections" {
  description = "max_connections for Postgres"
  type        = number
  default     = 200
}

variable "pg_log_statement" {
  description = "log_statement: none | ddl | mod | all"
  type        = string
  default     = "none"
}

variable "pg_work_mem" {
  description = "PostgreSQL work_mem in kilobytes (e.g., 4096 = 4MB)"
  type        = number
  default     = 4096
}

################################
# MySQL tuning vars
################################
variable "mysql_max_connections" {
  description = "max_connections for MySQL/Aurora MySQL"
  type        = number
  default     = 200
}

variable "mysql_general_log" {
  description = "Enable general_log (true/false)"
  type        = bool
  default     = false
}

variable "mysql_slow_query_log" {
  description = "Enable slow_query_log (true/false)"
  type        = bool
  default     = true
}

variable "mysql_long_query_time" {
  description = "long_query_time in seconds"
  type        = number
  default     = 2
}

variable "allowed_security_group_ids_map" {
  description = "Map of SG IDs allowed to access the DB port (keys are static names, values are SG IDs)"
  type        = map(string)
  default     = {}
}
