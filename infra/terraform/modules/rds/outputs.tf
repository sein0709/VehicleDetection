output "endpoint" {
  description = "Primary instance endpoint (host:port)"
  value       = aws_db_instance.primary.endpoint
}

output "address" {
  description = "Primary instance hostname"
  value       = aws_db_instance.primary.address
}

output "reader_endpoint" {
  description = "Read replica endpoint"
  value       = aws_db_instance.read_replica.endpoint
}

output "port" {
  value = aws_db_instance.primary.port
}

output "database_name" {
  value = aws_db_instance.primary.db_name
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing master credentials"
  value       = aws_db_instance.primary.master_user_secret[0].secret_arn
}

output "primary_arn" {
  description = "ARN of the primary RDS instance (needed for cross-region replica)"
  value       = aws_db_instance.primary.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
