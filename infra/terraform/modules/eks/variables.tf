variable "name_prefix" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "system_instance_types" {
  type = list(string)
}

variable "system_min_size" {
  type = number
}

variable "system_max_size" {
  type = number
}

variable "system_desired_size" {
  type = number
}

variable "gpu_instance_types" {
  type = list(string)
}

variable "gpu_min_size" {
  type = number
}

variable "gpu_max_size" {
  type = number
}

variable "gpu_desired_size" {
  type = number
}

variable "kms_key_arn" {
  description = "KMS key ARN for EKS secrets envelope encryption"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
