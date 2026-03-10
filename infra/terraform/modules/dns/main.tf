###############################################################################
# DNS & TLS Module
#
# Route 53 hosted zone, ACM certificate with DNS validation, and health checks
# for DR failover routing.
###############################################################################

# ── Route 53 Hosted Zone ────────────────────────────────────────────────────

resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = merge(var.tags, { Name = "${var.domain_name}-zone" })
}

# ── ACM Certificate (wildcard + apex) ───────────────────────────────────────

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(var.tags, { Name = "${var.domain_name}-cert" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ── Health Check (primary API endpoint) ──────────────────────────────────────

resource "aws_route53_health_check" "api_primary" {
  fqdn              = "${var.api_subdomain}.${var.domain_name}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/healthz"
  request_interval  = 10
  failure_threshold = 3

  tags = merge(var.tags, { Name = "${var.api_subdomain}.${var.domain_name}-health" })
}

# ── API DNS Record (placeholder — updated by Helm/ingress controller) ───────
# In production, the ALB/NLB ingress controller creates the actual A/ALIAS
# record. This record serves as the failover-aware wrapper.

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "${var.api_subdomain}.${var.domain_name}"
  type    = "A"
  ttl     = 60

  set_identifier = "primary-${var.aws_region}"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.api_primary.id

  records = ["127.0.0.1"]

  lifecycle {
    ignore_changes = [records, alias]
  }
}
