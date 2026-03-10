output "dr_replica_endpoint" {
  description = "DR replica endpoint (host:port)"
  value       = aws_db_instance.dr_replica.endpoint
}

output "dr_replica_address" {
  description = "DR replica hostname"
  value       = aws_db_instance.dr_replica.address
}

output "dr_replica_arn" {
  description = "DR replica ARN (needed for promotion)"
  value       = aws_db_instance.dr_replica.arn
}

output "dr_replica_identifier" {
  description = "DR replica instance identifier"
  value       = aws_db_instance.dr_replica.identifier
}

output "dr_security_group_id" {
  value = aws_security_group.dr.id
}

output "dr_kms_key_arn" {
  value = aws_kms_key.dr_rds.arn
}
