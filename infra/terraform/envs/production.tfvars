###############################################################################
# GreyEye — Production Environment
###############################################################################

environment = "production"
aws_region  = "ap-northeast-2"
dr_region   = "ap-northeast-1"

# Networking
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]

# EKS — System nodes
eks_cluster_version       = "1.29"
eks_system_instance_types = ["m6i.xlarge"]
eks_system_min_size       = 3
eks_system_max_size       = 10
eks_system_desired_size   = 3

# EKS — GPU nodes (inference workers)
eks_gpu_instance_types = ["g5.xlarge"]
eks_gpu_min_size       = 2
eks_gpu_max_size       = 20
eks_gpu_desired_size   = 2

# RDS PostgreSQL
rds_instance_class        = "db.r6g.xlarge"
rds_engine_version        = "16.2"
rds_allocated_storage     = 100
rds_max_allocated_storage = 500
rds_multi_az              = true
rds_backup_retention_period = 30

# ElastiCache Redis
redis_node_type          = "cache.r6g.large"
redis_num_cache_clusters = 3
redis_engine_version     = "7.1"

# DNS
domain_name   = "greyeye.io"
api_subdomain = "api"

# Disaster Recovery
enable_dr             = true
dr_vpc_cidr           = "10.2.0.0/16"
dr_availability_zones = ["ap-northeast-1a", "ap-northeast-1c"]
dr_instance_class     = "db.r6g.large"

tags = {
  Team        = "platform"
  CostCenter  = "greyeye-prod"
}
