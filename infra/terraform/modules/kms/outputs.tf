output "eks_key_arn" {
  value = aws_kms_key.eks.arn
}

output "rds_key_arn" {
  value = aws_kms_key.rds.arn
}

output "s3_key_arn" {
  value = aws_kms_key.s3.arn
}

output "elasticache_key_arn" {
  value = aws_kms_key.elasticache.arn
}
