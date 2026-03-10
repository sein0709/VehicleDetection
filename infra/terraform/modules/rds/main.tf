###############################################################################
# RDS Module
#
# Managed PostgreSQL 16 with:
# - Multi-AZ for HA
# - KMS encryption at rest
# - Automated backups (30-day retention)
# - Performance Insights
# - Enhanced monitoring
# - Read replica for analytics queries
###############################################################################

# ── Subnet Group ─────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-postgres"
  subnet_ids = var.private_subnets

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-subnet-group" })
}

# ── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "this" {
  name_prefix = "${var.name_prefix}-postgres-"
  description = "PostgreSQL access from EKS nodes"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.this.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

# ── Parameter Group ──────────────────────────────────────────────────────────

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name_prefix}-pg16-"
  family      = "postgres16"
  description = "GreyEye PostgreSQL 16 parameters"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "wal_level"
    value        = "replica"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "max_wal_senders"
    value = "5"
  }

  parameter {
    name  = "wal_keep_size"
    value = "1024"
  }

  parameter {
    name  = "archive_timeout"
    value = "300"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ── Enhanced Monitoring IAM Role ─────────────────────────────────────────────

resource "aws_iam_role" "monitoring" {
  name = "${var.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── Primary Instance ─────────────────────────────────────────────────────────

resource "aws_db_instance" "primary" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = "greyeye"
  username = var.master_username
  manage_master_user_password = true

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  backup_retention_period   = var.backup_retention
  backup_window             = "17:00-18:00"
  maintenance_window        = "sun:18:00-sun:19:00"
  copy_tags_to_snapshot     = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name_prefix}-postgres-final"

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.monitoring.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-primary" })
}

# ── Read Replica (analytics workload) ────────────────────────────────────────

resource "aws_db_instance" "read_replica" {
  identifier = "${var.name_prefix}-postgres-read"

  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.instance_class

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.monitoring.arn

  skip_final_snapshot = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-read-replica" })
}
