###############################################################################
# S3 Module
#
# Application buckets with:
# - SSE-KMS encryption
# - Versioning
# - Cross-region replication (CRR) for DR-critical buckets
# - Lifecycle rules per data retention policy
# - Public access block on all buckets
###############################################################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws, aws.dr]
    }
  }
}

data "aws_caller_identity" "current" {}

# ── Replication IAM Role ─────────────────────────────────────────────────────

resource "aws_iam_role" "replication" {
  name = "${var.name_prefix}-s3-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "replication" {
  name = "s3-replication"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.frames.arn,
          aws_s3_bucket.hard_examples.arn,
          aws_s3_bucket.models.arn,
          aws_s3_bucket.backups.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
        ]
        Resource = [
          "${aws_s3_bucket.frames.arn}/*",
          "${aws_s3_bucket.hard_examples.arn}/*",
          "${aws_s3_bucket.models.arn}/*",
          "${aws_s3_bucket.backups.arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Resource = [
          "${aws_s3_bucket.frames_dr.arn}/*",
          "${aws_s3_bucket.hard_examples_dr.arn}/*",
          "${aws_s3_bucket.models_dr.arn}/*",
          "${aws_s3_bucket.backups_dr.arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = ["*"]
      },
    ]
  })
}

# ═════════════════════════════════════════════════════════════════════════════
# PRIMARY REGION BUCKETS
# ═════════════════════════════════════════════════════════════════════════════

# ── Frames ───────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "frames" {
  bucket = "${var.name_prefix}-frames"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-frames" })
}

resource "aws_s3_bucket_versioning" "frames" {
  bucket = aws_s3_bucket.frames.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frames" {
  bucket = aws_s3_bucket.frames.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "frames" {
  bucket                  = aws_s3_bucket.frames.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "frames" {
  bucket = aws_s3_bucket.frames.id

  rule {
    id     = "expire-old-frames"
    status = "Enabled"
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

resource "aws_s3_bucket_replication_configuration" "frames" {
  depends_on = [aws_s3_bucket_versioning.frames]
  bucket     = aws_s3_bucket.frames.id
  role       = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.frames_dr.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# ── Exports ──────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "exports" {
  bucket = "${var.name_prefix}-exports"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-exports" })
}

resource "aws_s3_bucket_versioning" "exports" {
  bucket = aws_s3_bucket.exports.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    id     = "expire-exports"
    status = "Enabled"
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}

# ── Models ───────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "models" {
  bucket = "${var.name_prefix}-models"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-models" })
}

resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_replication_configuration" "models" {
  depends_on = [aws_s3_bucket_versioning.models]
  bucket     = aws_s3_bucket.models.id
  role       = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.models_dr.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# ── Hard Examples ────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "hard_examples" {
  bucket = "${var.name_prefix}-hard-examples"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-hard-examples" })
}

resource "aws_s3_bucket_versioning" "hard_examples" {
  bucket = aws_s3_bucket.hard_examples.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hard_examples" {
  bucket = aws_s3_bucket.hard_examples.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "hard_examples" {
  bucket                  = aws_s3_bucket.hard_examples.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_replication_configuration" "hard_examples" {
  depends_on = [aws_s3_bucket_versioning.hard_examples]
  bucket     = aws_s3_bucket.hard_examples.id
  role       = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.hard_examples_dr.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# ── Backups ──────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "backups" {
  bucket = "${var.name_prefix}-backups"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-backups" })
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "full-backup-retention"
    status = "Enabled"
    filter { prefix = "full/" }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }

  rule {
    id     = "diff-backup-retention"
    status = "Enabled"
    filter { prefix = "diff/" }
    expiration { days = 7 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }

  rule {
    id     = "wal-retention"
    status = "Enabled"
    filter { prefix = "wal/" }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

resource "aws_s3_bucket_replication_configuration" "backups" {
  depends_on = [aws_s3_bucket_versioning.backups]
  bucket     = aws_s3_bucket.backups.id
  role       = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.backups_dr.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# ═════════════════════════════════════════════════════════════════════════════
# DR REGION REPLICA BUCKETS
# ═════════════════════════════════════════════════════════════════════════════

resource "aws_s3_bucket" "frames_dr" {
  provider = aws.dr
  bucket   = "${var.name_prefix}-frames-dr"
  tags     = merge(var.tags, { Name = "${var.name_prefix}-frames-dr" })
}

resource "aws_s3_bucket_versioning" "frames_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.frames_dr.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "frames_dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.frames_dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "hard_examples_dr" {
  provider = aws.dr
  bucket   = "${var.name_prefix}-hard-examples-dr"
  tags     = merge(var.tags, { Name = "${var.name_prefix}-hard-examples-dr" })
}

resource "aws_s3_bucket_versioning" "hard_examples_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.hard_examples_dr.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "hard_examples_dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.hard_examples_dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "models_dr" {
  provider = aws.dr
  bucket   = "${var.name_prefix}-models-dr"
  tags     = merge(var.tags, { Name = "${var.name_prefix}-models-dr" })
}

resource "aws_s3_bucket_versioning" "models_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.models_dr.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "models_dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.models_dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "backups_dr" {
  provider = aws.dr
  bucket   = "${var.name_prefix}-backups-dr"
  tags     = merge(var.tags, { Name = "${var.name_prefix}-backups-dr" })
}

resource "aws_s3_bucket_versioning" "backups_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.backups_dr.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "backups_dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.backups_dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ═════════════════════════════════════════════════════════════════════════════
# TERRAFORM STATE BUCKET (bootstrapped separately, referenced here for docs)
# ═════════════════════════════════════════════════════════════════════════════
# The state bucket "greyeye-terraform-state" and DynamoDB lock table
# "greyeye-terraform-lock" must be created before running `terraform init`.
# See infra/terraform/bootstrap/ for the one-time bootstrap configuration.
