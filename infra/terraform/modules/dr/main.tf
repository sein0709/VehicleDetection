###############################################################################
# DR Module — Cross-Region Standby
#
# Creates a cross-region read replica in the DR region (ap-northeast-1 Tokyo)
# that can be promoted to a standalone primary during failover.
#
# Per docs/07-backup-and-recovery.md Section 8:
#   Active-passive; primary ap-northeast-2 (Seoul),
#   standby ap-northeast-1 (Tokyo)
###############################################################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws, aws.dr]
    }
  }
}

# ── DR Region Subnet Group ──────────────────────────────────────────────────

resource "aws_db_subnet_group" "dr" {
  provider = aws.dr

  name       = "${var.name_prefix}-postgres-dr"
  subnet_ids = var.dr_private_subnets

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-dr-subnet-group" })
}

# ── DR Region Security Group ────────────────────────────────────────────────

resource "aws_security_group" "dr" {
  provider = aws.dr

  name_prefix = "${var.name_prefix}-postgres-dr-"
  description = "PostgreSQL DR replica access"
  vpc_id      = var.dr_vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-dr-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "dr_ingress" {
  provider = aws.dr
  count    = length(var.dr_allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.dr_allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.dr.id
}

resource "aws_security_group_rule" "dr_egress" {
  provider = aws.dr

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.dr.id
}

# ── DR Region KMS Key ───────────────────────────────────────────────────────

resource "aws_kms_key" "dr_rds" {
  provider = aws.dr

  description             = "${var.name_prefix} DR RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-dr-rds-kms" })
}

resource "aws_kms_alias" "dr_rds" {
  provider = aws.dr

  name          = "alias/${var.name_prefix}-dr-rds"
  target_key_id = aws_kms_key.dr_rds.key_id
}

# ── Cross-Region Read Replica (async streaming replication) ─────────────────

resource "aws_db_instance" "dr_replica" {
  provider = aws.dr

  identifier          = "${var.name_prefix}-postgres-dr"
  replicate_source_db = var.source_db_arn
  instance_class      = var.dr_instance_class

  storage_encrypted = true
  kms_key_id        = aws_kms_key.dr_rds.arn

  db_subnet_group_name   = aws_db_subnet_group.dr.name
  vpc_security_group_ids = [aws_security_group.dr.id]

  multi_az = false

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.dr_rds.arn
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.dr_monitoring.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  skip_final_snapshot = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres-dr-replica"
    Role = "dr-standby"
  })
}

# ── DR Enhanced Monitoring IAM ──────────────────────────────────────────────

resource "aws_iam_role" "dr_monitoring" {
  provider = aws.dr

  name = "${var.name_prefix}-rds-dr-monitoring"

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

resource "aws_iam_role_policy_attachment" "dr_monitoring" {
  provider = aws.dr

  role       = aws_iam_role.dr_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── CloudWatch Alarms for DR Replication Lag ────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "dr_replication_lag" {
  provider = aws.dr

  alarm_name          = "${var.name_prefix}-dr-replication-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ReplicaLag"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 900
  alarm_description   = "DR replica lag exceeds 15 minutes (RPO threshold)"
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.dr_replica.identifier
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = var.tags
}
