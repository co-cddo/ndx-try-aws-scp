terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# =============================================================================
# AWS SERVICE QUOTAS MANAGER
# =============================================================================
# Service Quotas complement SCPs by limiting the NUMBER of resources.
# SCPs control WHAT you can do; Service Quotas control HOW MUCH.
#
# Key insight: Each sandbox lease is 24 hours. Quotas are designed to limit
# maximum possible spend within that window while still allowing legitimate
# experimentation.
#
# These use Service Quota Templates which automatically apply to accounts
# in the organization when they're created or when template association is enabled.
# =============================================================================

# -----------------------------------------------------------------------------
# EC2 SERVICE QUOTAS
# -----------------------------------------------------------------------------
# These are the most critical for cost control as EC2 is often the largest
# spend category. On-Demand vCPU limits prevent mass instance provisioning.

resource "aws_servicequotas_template" "ec2_on_demand_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-1216C47A" # Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_on_demand_vcpu_limit

  # Note: This quota controls vCPUs, not instance count
  # At 64 vCPUs: max 64 t3.micro, or 8 m5.xlarge, etc.
}

resource "aws_servicequotas_template" "ec2_spot_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-34B43A08" # All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_spot_vcpu_limit
}

# G and VT instances (GPU/Graphics) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_gpu_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-DB2E81BA" # Running On-Demand G and VT instances
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_gpu_vcpu_limit # Default: 0
}

# P instances (ML/GPU) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_p_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-417A185B" # Running On-Demand P instances
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_p_instance_vcpu_limit # Default: 0
}

# Inf instances (Inferentia) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_inf_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-1945E190" # Running On-Demand Inf instances
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_inf_vcpu_limit # Default: 0
}

# DL instances (Deep Learning) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_dl_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-6E869C2A" # Running On-Demand DL instances
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_dl_vcpu_limit # Default: 0
}

# Trn instances (Trainium) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_trn_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-2C49D5F8" # Running On-Demand Trn instances
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_trn_vcpu_limit # Default: 0
}

# High Memory instances - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_high_mem_vcpus" {
  count = var.enable_ec2_quotas ? 1 : 0

  quota_code   = "L-43DA4232" # Running On-Demand High Memory instances
  service_code = "ec2"
  region       = var.primary_region
  value        = var.ec2_high_mem_vcpu_limit # Default: 0
}

# -----------------------------------------------------------------------------
# EBS SERVICE QUOTAS
# -----------------------------------------------------------------------------
# EBS storage can accumulate quickly. Limiting total storage prevents
# someone from creating many large volumes.

resource "aws_servicequotas_template" "ebs_storage_gp3" {
  count = var.enable_ebs_quotas ? 1 : 0

  quota_code   = "L-7A658B76" # Storage for gp3 volumes in TiB
  service_code = "ebs"
  region       = var.primary_region
  value        = var.ebs_gp3_storage_tib # Default: 1 TiB (1024 GB)
}

resource "aws_servicequotas_template" "ebs_storage_gp2" {
  count = var.enable_ebs_quotas ? 1 : 0

  quota_code   = "L-D18FCD1D" # Storage for gp2 volumes in TiB
  service_code = "ebs"
  region       = var.primary_region
  value        = var.ebs_gp2_storage_tib # Default: 1 TiB
}

# io1/io2 IOPS - should be 0 since we block these in SCP
resource "aws_servicequotas_template" "ebs_io1_iops" {
  count = var.enable_ebs_quotas ? 1 : 0

  quota_code   = "L-B3A130E6" # IOPS for Provisioned IOPS SSD (io1) volumes
  service_code = "ebs"
  region       = var.primary_region
  value        = var.ebs_io1_iops_limit # Default: 0
}

resource "aws_servicequotas_template" "ebs_io2_iops" {
  count = var.enable_ebs_quotas ? 1 : 0

  quota_code   = "L-8D977E7E" # IOPS for Provisioned IOPS SSD (io2) volumes
  service_code = "ebs"
  region       = var.primary_region
  value        = var.ebs_io2_iops_limit # Default: 0
}

# Snapshots - limit to prevent snapshot sprawl
resource "aws_servicequotas_template" "ebs_snapshots" {
  count = var.enable_ebs_quotas ? 1 : 0

  quota_code   = "L-309BACF6" # Number of EBS snapshots
  service_code = "ebs"
  region       = var.primary_region
  value        = var.ebs_snapshot_limit # Default: 100
}

# -----------------------------------------------------------------------------
# LAMBDA SERVICE QUOTAS
# -----------------------------------------------------------------------------
# Lambda concurrent executions can generate significant cost if uncontrolled.

resource "aws_servicequotas_template" "lambda_concurrent_executions" {
  count = var.enable_lambda_quotas ? 1 : 0

  quota_code   = "L-B99A9384" # Concurrent executions
  service_code = "lambda"
  region       = var.primary_region
  value        = var.lambda_concurrent_executions # Default: 100
}

# -----------------------------------------------------------------------------
# VPC SERVICE QUOTAS
# -----------------------------------------------------------------------------
# VPC resources have per-hour costs (NAT Gateways) and can multiply quickly.

resource "aws_servicequotas_template" "vpc_count" {
  count = var.enable_vpc_quotas ? 1 : 0

  quota_code   = "L-F678F1CE" # VPCs per Region
  service_code = "vpc"
  region       = var.primary_region
  value        = var.vpc_limit # Default: 5
}

resource "aws_servicequotas_template" "nat_gateways" {
  count = var.enable_vpc_quotas ? 1 : 0

  quota_code   = "L-FE5A380F" # NAT gateways per Availability Zone
  service_code = "vpc"
  region       = var.primary_region
  value        = var.nat_gateway_per_az_limit # Default: 2
}

resource "aws_servicequotas_template" "elastic_ips" {
  count = var.enable_vpc_quotas ? 1 : 0

  quota_code   = "L-0263D0A3" # EC2-VPC Elastic IPs
  service_code = "ec2"
  region       = var.primary_region
  value        = var.elastic_ip_limit # Default: 5
}

# -----------------------------------------------------------------------------
# RDS SERVICE QUOTAS
# -----------------------------------------------------------------------------
# RDS instances are expensive and can multiply via replicas.

resource "aws_servicequotas_template" "rds_instances" {
  count = var.enable_rds_quotas ? 1 : 0

  quota_code   = "L-7B6409FD" # DB instances
  service_code = "rds"
  region       = var.primary_region
  value        = var.rds_instance_limit # Default: 5
}

resource "aws_servicequotas_template" "rds_storage" {
  count = var.enable_rds_quotas ? 1 : 0

  quota_code   = "L-7ADDB58A" # Total storage for all DB instances (GB)
  service_code = "rds"
  region       = var.primary_region
  value        = var.rds_total_storage_gb # Default: 500 GB
}

resource "aws_servicequotas_template" "rds_read_replicas" {
  count = var.enable_rds_quotas ? 1 : 0

  quota_code   = "L-5BC124EF" # Read replicas per source DB instance
  service_code = "rds"
  region       = var.primary_region
  value        = var.rds_read_replicas_per_source # Default: 0 (blocked in SCP too)
}

# -----------------------------------------------------------------------------
# ELASTICACHE SERVICE QUOTAS
# -----------------------------------------------------------------------------

resource "aws_servicequotas_template" "elasticache_nodes" {
  count = var.enable_elasticache_quotas ? 1 : 0

  quota_code   = "L-9B87FA9D" # Nodes per Region
  service_code = "elasticache"
  region       = var.primary_region
  value        = var.elasticache_node_limit # Default: 10
}

# -----------------------------------------------------------------------------
# EKS SERVICE QUOTAS
# -----------------------------------------------------------------------------

resource "aws_servicequotas_template" "eks_clusters" {
  count = var.enable_eks_quotas ? 1 : 0

  quota_code   = "L-1194D53C" # Clusters
  service_code = "eks"
  region       = var.primary_region
  value        = var.eks_cluster_limit # Default: 2
}

# -----------------------------------------------------------------------------
# LOAD BALANCER SERVICE QUOTAS
# -----------------------------------------------------------------------------
# Load balancers have hourly costs that add up.

resource "aws_servicequotas_template" "alb_count" {
  count = var.enable_elb_quotas ? 1 : 0

  quota_code   = "L-53DA6B97" # Application Load Balancers per Region
  service_code = "elasticloadbalancing"
  region       = var.primary_region
  value        = var.alb_limit # Default: 5
}

resource "aws_servicequotas_template" "nlb_count" {
  count = var.enable_elb_quotas ? 1 : 0

  quota_code   = "L-69A177A2" # Network Load Balancers per Region
  service_code = "elasticloadbalancing"
  region       = var.primary_region
  value        = var.nlb_limit # Default: 5
}

# -----------------------------------------------------------------------------
# DYNAMODB SERVICE QUOTAS
# -----------------------------------------------------------------------------
# DynamoDB capacity can generate massive bills if uncontrolled.
# NOTE: These quotas apply to provisioned capacity mode only.
# On-demand mode has no quota for capacity but is pay-per-request.

resource "aws_servicequotas_template" "dynamodb_table_count" {
  count = var.enable_dynamodb_quotas ? 1 : 0

  quota_code   = "L-F98FE922" # Maximum number of tables
  service_code = "dynamodb"
  region       = var.primary_region
  value        = var.dynamodb_table_limit # Default: 50
}

# Account-wide RCU/WCU limits don't exist as service quotas.
# DynamoDB capacity is controlled per-table, which SCPs cannot limit.
# Recommendation: Use AWS Budgets with actions for DynamoDB.

# -----------------------------------------------------------------------------
# KINESIS SERVICE QUOTAS
# -----------------------------------------------------------------------------
# Kinesis streams have per-shard-hour pricing.

resource "aws_servicequotas_template" "kinesis_shards" {
  count = var.enable_kinesis_quotas ? 1 : 0

  quota_code   = "L-53A1086E" # Shards per Region
  service_code = "kinesis"
  region       = var.primary_region
  value        = var.kinesis_shard_limit # Default: 0 (blocked in SCP)
}

# -----------------------------------------------------------------------------
# CLOUDWATCH SERVICE QUOTAS
# -----------------------------------------------------------------------------
# CloudWatch logs ingestion can generate unexpected costs.

resource "aws_servicequotas_template" "cloudwatch_log_groups" {
  count = var.enable_cloudwatch_quotas ? 1 : 0

  quota_code   = "L-D2832119" # Log groups
  service_code = "logs"
  region       = var.primary_region
  value        = var.cloudwatch_log_group_limit # Default: 50
}

# -----------------------------------------------------------------------------
# SERVICE QUOTA TEMPLATE ASSOCIATION
# -----------------------------------------------------------------------------
# Associates the quota templates with the organization.
# Once associated, quotas automatically apply to new accounts.

resource "aws_servicequotas_template_association" "sandbox" {
  count = var.enable_template_association ? 1 : 0
}

# -----------------------------------------------------------------------------
# SECONDARY REGION SUPPORT
# -----------------------------------------------------------------------------
# Some quotas need to be set in the secondary region as well.
# Only creating critical quotas for secondary region.

resource "aws_servicequotas_template" "ec2_on_demand_vcpus_secondary" {
  count = var.enable_ec2_quotas && var.secondary_region != null ? 1 : 0

  quota_code   = "L-1216C47A"
  service_code = "ec2"
  region       = var.secondary_region
  value        = var.ec2_on_demand_vcpu_limit
}

resource "aws_servicequotas_template" "ec2_gpu_vcpus_secondary" {
  count = var.enable_ec2_quotas && var.secondary_region != null ? 1 : 0

  quota_code   = "L-DB2E81BA"
  service_code = "ec2"
  region       = var.secondary_region
  value        = var.ec2_gpu_vcpu_limit
}

resource "aws_servicequotas_template" "ec2_p_vcpus_secondary" {
  count = var.enable_ec2_quotas && var.secondary_region != null ? 1 : 0

  quota_code   = "L-417A185B"
  service_code = "ec2"
  region       = var.secondary_region
  value        = var.ec2_p_instance_vcpu_limit
}

resource "aws_servicequotas_template" "ebs_storage_gp3_secondary" {
  count = var.enable_ebs_quotas && var.secondary_region != null ? 1 : 0

  quota_code   = "L-7A658B76"
  service_code = "ebs"
  region       = var.secondary_region
  value        = var.ebs_gp3_storage_tib
}

resource "aws_servicequotas_template" "lambda_concurrent_secondary" {
  count = var.enable_lambda_quotas && var.secondary_region != null ? 1 : 0

  quota_code   = "L-B99A9384"
  service_code = "lambda"
  region       = var.secondary_region
  value        = var.lambda_concurrent_executions
}
