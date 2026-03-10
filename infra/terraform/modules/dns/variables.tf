variable "domain_name" {
  type = string
}

variable "api_subdomain" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
