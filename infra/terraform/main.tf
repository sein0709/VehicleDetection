###############################################################################
# GreyEye — Root Module
#
# Orchestrates all infrastructure modules for the GreyEye platform.
# Primary region: ap-northeast-2 (Seoul)
# DR region:      ap-northeast-1 (Tokyo)
###############################################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── VPC ──────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  tags               = local.common_tags
}

# ── KMS ──────────────────────────────────────────────────────────────────────

module "kms" {
  source = "./modules/kms"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ── EKS Cluster ──────────────────────────────────────────────────────────────

module "eks" {
  source = "./modules/eks"

  name_prefix     = local.name_prefix
  cluster_version = var.eks_cluster_version

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids

  system_instance_types = var.eks_system_instance_types
  system_min_size       = var.eks_system_min_size
  system_max_size       = var.eks_system_max_size
  system_desired_size   = var.eks_system_desired_size

  gpu_instance_types = var.eks_gpu_instance_types
  gpu_min_size       = var.eks_gpu_min_size
  gpu_max_size       = var.eks_gpu_max_size
  gpu_desired_size   = var.eks_gpu_desired_size

  kms_key_arn = module.kms.eks_key_arn

  tags = local.common_tags
}

# ── RDS PostgreSQL ───────────────────────────────────────────────────────────

module "rds" {
  source = "./modules/rds"

  name_prefix = local.name_prefix

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.data_subnet_ids
  allowed_security_group_ids = [
    module.eks.node_security_group_id,
  ]

  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  multi_az              = var.rds_multi_az
  backup_retention      = var.rds_backup_retention_period
  master_username       = var.rds_master_username
  kms_key_arn           = module.kms.rds_key_arn

  tags = local.common_tags
}

# ── S3 Buckets ───────────────────────────────────────────────────────────────

module "s3" {
  source = "./modules/s3"

  name_prefix = local.name_prefix
  aws_region  = var.aws_region
  dr_region   = var.dr_region
  kms_key_arn = module.kms.s3_key_arn

  tags = local.common_tags

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }
}

# ── ElastiCache Redis ────────────────────────────────────────────────────────

module "elasticache" {
  source = "./modules/elasticache"

  name_prefix = local.name_prefix

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.data_subnet_ids
  allowed_security_group_ids = [
    module.eks.node_security_group_id,
  ]

  node_type          = var.redis_node_type
  num_cache_clusters = var.redis_num_cache_clusters
  engine_version     = var.redis_engine_version
  kms_key_arn        = module.kms.elasticache_key_arn

  tags = local.common_tags
}

# ── NATS JetStream (Helm on EKS) ────────────────────────────────────────────

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "nats" {
  source = "./modules/nats"

  name_prefix = local.name_prefix
  namespace   = "greyeye-data"

  depends_on = [module.eks]
}

# ── DR Region VPC ────────────────────────────────────────────────────────────

module "vpc_dr" {
  source = "./modules/vpc"
  count  = var.enable_dr ? 1 : 0

  providers = { aws = aws.dr }

  name_prefix        = "${local.name_prefix}-dr"
  vpc_cidr           = var.dr_vpc_cidr
  availability_zones = var.dr_availability_zones
  tags               = merge(local.common_tags, { Region = "dr" })
}

# ── DR Cross-Region Replica ──────────────────────────────────────────────────

module "dr" {
  source = "./modules/dr"
  count  = var.enable_dr ? 1 : 0

  name_prefix = local.name_prefix

  source_db_arn      = module.rds.primary_arn
  dr_vpc_id          = module.vpc_dr[0].vpc_id
  dr_private_subnets = module.vpc_dr[0].data_subnet_ids

  dr_instance_class    = var.dr_instance_class
  alarm_sns_topic_arns = var.dr_alarm_sns_topic_arns

  tags = local.common_tags

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  depends_on = [module.rds]
}

# ── DNS & TLS ────────────────────────────────────────────────────────────────

module "dns" {
  source = "./modules/dns"

  domain_name   = var.domain_name
  api_subdomain = var.api_subdomain
  aws_region    = var.aws_region

  tags = local.common_tags
}

# ── WAF (SEC-13) ──────────────────────────────────────────────────────────

module "waf" {
  source = "./modules/waf"

  name_prefix           = local.name_prefix
  alb_arn               = var.alb_arn
  blocked_country_codes = var.waf_blocked_country_codes
  rate_limit_per_ip     = var.waf_rate_limit_per_ip

  tags = local.common_tags
}
