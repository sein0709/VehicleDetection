###############################################################################
# GreyEye — Root Outputs
###############################################################################

# ── VPC ──────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# ── EKS ──────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

# ── RDS ──────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "RDS primary endpoint"
  value       = module.rds.endpoint
}

output "rds_reader_endpoint" {
  description = "RDS reader endpoint"
  value       = module.rds.reader_endpoint
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.port
}

# ── S3 ───────────────────────────────────────────────────────────────────────

output "s3_bucket_frames" {
  description = "S3 bucket name for video frames"
  value       = module.s3.bucket_frames
}

output "s3_bucket_exports" {
  description = "S3 bucket name for report exports"
  value       = module.s3.bucket_exports
}

output "s3_bucket_models" {
  description = "S3 bucket name for ML model artifacts"
  value       = module.s3.bucket_models
}

output "s3_bucket_hard_examples" {
  description = "S3 bucket name for hard-example images"
  value       = module.s3.bucket_hard_examples
}

output "s3_bucket_backups" {
  description = "S3 bucket name for database backups"
  value       = module.s3.bucket_backups
}

# ── Redis ────────────────────────────────────────────────────────────────────

output "redis_primary_endpoint" {
  description = "Redis primary endpoint address"
  value       = module.elasticache.primary_endpoint
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint address"
  value       = module.elasticache.reader_endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = module.elasticache.port
}

# ── DNS ──────────────────────────────────────────────────────────────────────

output "api_domain" {
  description = "Fully-qualified API domain name"
  value       = module.dns.api_fqdn
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN for TLS"
  value       = module.dns.certificate_arn
}

output "nameservers" {
  description = "Route 53 nameservers (delegate from registrar)"
  value       = module.dns.nameservers
}

# ── DR ────────────────────────────────────────────────────────────────────────

output "dr_replica_endpoint" {
  description = "DR cross-region replica endpoint"
  value       = var.enable_dr ? module.dr[0].dr_replica_endpoint : null
}

output "dr_replica_identifier" {
  description = "DR replica instance identifier (needed for promotion)"
  value       = var.enable_dr ? module.dr[0].dr_replica_identifier : null
}
