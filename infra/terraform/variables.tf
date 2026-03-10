###############################################################################
# GreyEye — Root Variables
###############################################################################

variable "project" {
  description = "Project name used as a prefix for all resources"
  type        = string
  default     = "greyeye"
}

variable "environment" {
  description = "Deployment environment (staging | production)"
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production"
  }
}

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "dr_region" {
  description = "Disaster-recovery AWS region for CRR and standby"
  type        = string
  default     = "ap-northeast-1"
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs within the primary region (minimum 2 for multi-AZ)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}

# ── EKS ──────────────────────────────────────────────────────────────────────

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "eks_system_instance_types" {
  description = "Instance types for the system (non-GPU) node group"
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "eks_system_min_size" {
  type    = number
  default = 2
}

variable "eks_system_max_size" {
  type    = number
  default = 10
}

variable "eks_system_desired_size" {
  type    = number
  default = 3
}

variable "eks_gpu_instance_types" {
  description = "GPU instance types for the inference worker node group"
  type        = list(string)
  default     = ["g5.xlarge"]
}

variable "eks_gpu_min_size" {
  type    = number
  default = 0
}

variable "eks_gpu_max_size" {
  type    = number
  default = 10
}

variable "eks_gpu_desired_size" {
  type    = number
  default = 2
}

# ── RDS (PostgreSQL) ─────────────────────────────────────────────────────────

variable "rds_instance_class" {
  description = "RDS instance class for the primary PostgreSQL instance"
  type        = string
  default     = "db.r6g.xlarge"
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 100
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage for autoscaling in GiB"
  type        = number
  default     = 500
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.2"
}

variable "rds_multi_az" {
  description = "Enable multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 30
}

variable "rds_master_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "greyeye_admin"
  sensitive   = true
}

# ── ElastiCache (Redis) ─────────────────────────────────────────────────────

variable "redis_node_type" {
  description = "ElastiCache node type for Redis"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters (nodes) in the replication group"
  type        = number
  default     = 3
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

# ── DNS ──────────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Root domain for the GreyEye platform"
  type        = string
  default     = "greyeye.io"
}

variable "api_subdomain" {
  description = "Subdomain for the API endpoint"
  type        = string
  default     = "api"
}

# ── Disaster Recovery ────────────────────────────────────────────────────────

variable "enable_dr" {
  description = "Enable cross-region DR replica and DR VPC"
  type        = bool
  default     = false
}

variable "dr_vpc_cidr" {
  description = "CIDR block for the DR region VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "dr_availability_zones" {
  description = "AZs in the DR region"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "dr_instance_class" {
  description = "RDS instance class for the DR cross-region replica"
  type        = string
  default     = "db.r6g.large"
}

variable "dr_alarm_sns_topic_arns" {
  description = "SNS topic ARNs for DR replication lag alarms"
  type        = list(string)
  default     = []
}

# ── WAF (SEC-13) ──────────────────────────────────────────────────────────────

variable "alb_arn" {
  description = "ARN of the ALB to associate the WAF with (empty = no association)"
  type        = string
  default     = ""
}

variable "waf_blocked_country_codes" {
  description = "ISO 3166-1 alpha-2 country codes to block (empty = no geo-blocking)"
  type        = list(string)
  default     = []
}

variable "waf_rate_limit_per_ip" {
  description = "Maximum requests per 5-minute window per IP (WAF-level)"
  type        = number
  default     = 2000
}

# ── Tags ─────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
