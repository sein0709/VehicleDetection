output "nats_url" {
  description = "In-cluster NATS connection URL"
  value       = "nats://${var.name_prefix}-nats.${var.namespace}.svc:4222"
}

output "namespace" {
  value = var.namespace
}
