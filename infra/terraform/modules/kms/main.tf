###############################################################################
# KMS Module
#
# Customer-managed encryption keys for EKS secrets, RDS, S3, and ElastiCache.
###############################################################################

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ── EKS Envelope Encryption ─────────────────────────────────────────────────

resource "aws_kms_key" "eks" {
  description             = "${var.name_prefix} EKS secrets encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-eks-kms" })

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RootAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.name_prefix}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ── RDS Encryption ───────────────────────────────────────────────────────────

resource "aws_kms_key" "rds" {
  description             = "${var.name_prefix} RDS encryption at rest"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-rds-kms" })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ── S3 Encryption (SSE-KMS) ─────────────────────────────────────────────────

resource "aws_kms_key" "s3" {
  description             = "${var.name_prefix} S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-s3-kms" })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.name_prefix}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ── ElastiCache Encryption ──────────────────────────────────────────────────

resource "aws_kms_key" "elasticache" {
  description             = "${var.name_prefix} ElastiCache encryption at rest"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-elasticache-kms" })
}

resource "aws_kms_alias" "elasticache" {
  name          = "alias/${var.name_prefix}-elasticache"
  target_key_id = aws_kms_key.elasticache.key_id
}
