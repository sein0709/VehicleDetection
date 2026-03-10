###############################################################################
# GreyEye — Staging Environment
#
# Smaller instances and reduced redundancy to control costs while still
# exercising the full infrastructure topology.
###############################################################################

environment = "staging"
aws_region  = "ap-northeast-2"
dr_region   = "ap-northeast-1"

# Networking
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2b"]

# EKS — System nodes
eks_cluster_version       = "1.29"
eks_system_instance_types = ["m6i.large"]
eks_system_min_size       = 2
eks_system_max_size       = 5
eks_system_desired_size   = 2

# EKS — GPU nodes
eks_gpu_instance_types = ["g5.xlarge"]
eks_gpu_min_size       = 0
eks_gpu_max_size       = 3
eks_gpu_desired_size   = 1

# RDS PostgreSQL
rds_instance_class        = "db.r6g.large"
rds_engine_version        = "16.2"
rds_allocated_storage     = 50
rds_max_allocated_storage = 200
rds_multi_az              = false
rds_backup_retention_period = 7

# ElastiCache Redis
redis_node_type          = "cache.r6g.large"
redis_num_cache_clusters = 2
redis_engine_version     = "7.1"

# DNS
domain_name   = "greyeye.io"
api_subdomain = "api-staging"

# Disaster Recovery (disabled in staging to save costs)
enable_dr = false

tags = {
  Team        = "platform"
  CostCenter  = "greyeye-staging"
}
