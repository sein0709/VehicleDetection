variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "dr_region" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
