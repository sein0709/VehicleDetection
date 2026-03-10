variable "name_prefix" {
  type = string
}

variable "source_db_arn" {
  description = "ARN of the primary RDS instance to replicate from"
  type        = string
}

variable "dr_vpc_id" {
  description = "VPC ID in the DR region"
  type        = string
}

variable "dr_private_subnets" {
  description = "Private subnet IDs in the DR region for the replica"
  type        = list(string)
}

variable "dr_allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the DR replica"
  type        = list(string)
  default     = []
}

variable "dr_instance_class" {
  description = "Instance class for the DR replica (can be smaller than primary)"
  type        = string
  default     = "db.r6g.large"
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for DR replication lag alarms"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
