variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "max_body_size_bytes" {
  type        = number
  default     = 10485760 # 10 MB
  description = "Maximum request body size for non-upload endpoints"
}

variable "max_uri_size_bytes" {
  type        = number
  default     = 8192 # 8 KB
  description = "Maximum URI path length"
}

variable "rate_limit_per_ip" {
  type        = number
  default     = 2000
  description = "Maximum requests per 5-minute window per IP (WAF-level)"
}

variable "blocked_country_codes" {
  type        = list(string)
  default     = []
  description = "ISO 3166-1 alpha-2 country codes to block (empty = no geo-blocking)"
}

variable "alb_arn" {
  type        = string
  default     = ""
  description = "ARN of the ALB to associate the WAF with"
}

variable "log_retention_days" {
  type        = number
  default     = 90
  description = "CloudWatch log retention for WAF logs"
}
