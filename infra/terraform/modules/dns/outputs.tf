output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "nameservers" {
  value = aws_route53_zone.main.name_servers
}

output "api_fqdn" {
  value = "${var.api_subdomain}.${var.domain_name}"
}

output "certificate_arn" {
  value = aws_acm_certificate.main.arn
}

output "health_check_id" {
  value = aws_route53_health_check.api_primary.id
}
