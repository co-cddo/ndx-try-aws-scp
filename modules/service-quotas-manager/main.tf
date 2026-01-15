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
#
# MULTI-REGION SUPPORT:
# All quotas are applied to every region in var.regions using for_each.
# This ensures consistent limits across all allowed regions.
# =============================================================================

# -----------------------------------------------------------------------------
# EC2 SERVICE QUOTAS
# -----------------------------------------------------------------------------
# These are the most critical for cost control as EC2 is often the largest
# spend category. On-Demand vCPU limits prevent mass instance provisioning.

resource "aws_servicequotas_template" "ec2_on_demand_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-1216C47A" # Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_on_demand_vcpu_limit

  # Note: This quota controls vCPUs, not instance count
  # At 64 vCPUs: max 64 t3.micro, or 8 m5.xlarge, etc.
}

resource "aws_servicequotas_template" "ec2_spot_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-34B43A08" # All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_spot_vcpu_limit
}

# G and VT instances (GPU/Graphics) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_gpu_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-DB2E81BA" # Running On-Demand G and VT instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_gpu_vcpu_limit
}

# P instances (ML/GPU) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_p_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-417A185B" # Running On-Demand P instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_p_instance_vcpu_limit
}

# Inf instances (Inferentia) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_inf_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-1945E190" # Running On-Demand Inf instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_inf_vcpu_limit
}

# DL instances (Deep Learning) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_dl_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-6E869C2A" # Running On-Demand DL instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_dl_vcpu_limit
}

# Trn instances (Trainium) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_trn_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-2C49D5F8" # Running On-Demand Trn instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_trn_vcpu_limit
}

# High Memory instances - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_high_mem_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-43DA4232" # Running On-Demand High Memory instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_high_mem_vcpu_limit
}

# -----------------------------------------------------------------------------
# EBS SERVICE QUOTAS
# -----------------------------------------------------------------------------
# EBS storage can accumulate quickly. Limiting total storage prevents
# someone from creating many large volumes.

resource "aws_servicequotas_template" "ebs_storage_gp3" {
  for_each = var.enable_ebs_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-7A658B76" # Storage for gp3 volumes in TiB
  service_code = "ebs"
  aws_region   = each.value
  value        = var.ebs_gp3_storage_tib
}

resource "aws_servicequotas_template" "ebs_storage_gp2" {
  for_each = var.enable_ebs_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-D18FCD1D" # Storage for gp2 volumes in TiB
  service_code = "ebs"
  aws_region   = each.value
  value        = var.ebs_gp2_storage_tib
}

# io1/io2 IOPS - should be 0 since we block these in SCP
resource "aws_servicequotas_template" "ebs_io1_iops" {
  for_each = var.enable_ebs_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-B3A130E6" # IOPS for Provisioned IOPS SSD (io1) volumes
  service_code = "ebs"
  aws_region   = each.value
  value        = var.ebs_io1_iops_limit
}

resource "aws_servicequotas_template" "ebs_io2_iops" {
  for_each = var.enable_ebs_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-8D977E7E" # IOPS for Provisioned IOPS SSD (io2) volumes
  service_code = "ebs"
  aws_region   = each.value
  value        = var.ebs_io2_iops_limit
}

# Snapshots - limit to prevent snapshot sprawl
resource "aws_servicequotas_template" "ebs_snapshots" {
  for_each = var.enable_ebs_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-309BACF6" # Number of EBS snapshots
  service_code = "ebs"
  aws_region   = each.value
  value        = var.ebs_snapshot_limit
}

# -----------------------------------------------------------------------------
# LAMBDA SERVICE QUOTAS
# -----------------------------------------------------------------------------
# Lambda concurrent executions can generate significant cost if uncontrolled.

resource "aws_servicequotas_template" "lambda_concurrent_executions" {
  for_each = var.enable_lambda_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-B99A9384" # Concurrent executions
  service_code = "lambda"
  aws_region   = each.value
  value        = var.lambda_concurrent_executions
}

# -----------------------------------------------------------------------------
# VPC SERVICE QUOTAS
# -----------------------------------------------------------------------------
# VPC resources have per-hour costs (NAT Gateways) and can multiply quickly.

resource "aws_servicequotas_template" "vpc_count" {
  for_each = var.enable_vpc_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-F678F1CE" # VPCs per Region
  service_code = "vpc"
  aws_region   = each.value
  value        = var.vpc_limit
}

resource "aws_servicequotas_template" "nat_gateways" {
  for_each = var.enable_vpc_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-FE5A380F" # NAT gateways per Availability Zone
  service_code = "vpc"
  aws_region   = each.value
  value        = var.nat_gateway_per_az_limit
}

resource "aws_servicequotas_template" "elastic_ips" {
  for_each = var.enable_vpc_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-0263D0A3" # EC2-VPC Elastic IPs
  service_code = "ec2"
  aws_region   = each.value
  value        = var.elastic_ip_limit
}

# -----------------------------------------------------------------------------
# RDS SERVICE QUOTAS
# -----------------------------------------------------------------------------
# RDS instances are expensive and can multiply via replicas.

resource "aws_servicequotas_template" "rds_instances" {
  for_each = var.enable_rds_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-7B6409FD" # DB instances
  service_code = "rds"
  aws_region   = each.value
  value        = var.rds_instance_limit
}

resource "aws_servicequotas_template" "rds_storage" {
  for_each = var.enable_rds_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-7ADDB58A" # Total storage for all DB instances (GB)
  service_code = "rds"
  aws_region   = each.value
  value        = var.rds_total_storage_gb
}

resource "aws_servicequotas_template" "rds_read_replicas" {
  for_each = var.enable_rds_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-5BC124EF" # Read replicas per source DB instance
  service_code = "rds"
  aws_region   = each.value
  value        = var.rds_read_replicas_per_source
}

# -----------------------------------------------------------------------------
# ELASTICACHE SERVICE QUOTAS
# -----------------------------------------------------------------------------

resource "aws_servicequotas_template" "elasticache_nodes" {
  for_each = var.enable_elasticache_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-9B87FA9D" # Nodes per Region
  service_code = "elasticache"
  aws_region   = each.value
  value        = var.elasticache_node_limit
}

# -----------------------------------------------------------------------------
# EKS SERVICE QUOTAS
# -----------------------------------------------------------------------------

resource "aws_servicequotas_template" "eks_clusters" {
  for_each = var.enable_eks_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-1194D53C" # Clusters
  service_code = "eks"
  aws_region   = each.value
  value        = var.eks_cluster_limit
}

# -----------------------------------------------------------------------------
# LOAD BALANCER SERVICE QUOTAS
# -----------------------------------------------------------------------------
# Load balancers have hourly costs that add up.

resource "aws_servicequotas_template" "alb_count" {
  for_each = var.enable_elb_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-53DA6B97" # Application Load Balancers per Region
  service_code = "elasticloadbalancing"
  aws_region   = each.value
  value        = var.alb_limit
}

resource "aws_servicequotas_template" "nlb_count" {
  for_each = var.enable_elb_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-69A177A2" # Network Load Balancers per Region
  service_code = "elasticloadbalancing"
  aws_region   = each.value
  value        = var.nlb_limit
}

# -----------------------------------------------------------------------------
# DYNAMODB SERVICE QUOTAS
# -----------------------------------------------------------------------------
# DynamoDB capacity can generate massive bills if uncontrolled.
# NOTE: These quotas apply to provisioned capacity mode only.
# On-demand mode has no quota for capacity but is pay-per-request.

resource "aws_servicequotas_template" "dynamodb_table_count" {
  for_each = var.enable_dynamodb_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-F98FE922" # Maximum number of tables
  service_code = "dynamodb"
  aws_region   = each.value
  value        = var.dynamodb_table_limit
}

# DynamoDB account-level capacity limits
resource "aws_servicequotas_template" "dynamodb_read_capacity" {
  for_each = var.enable_dynamodb_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-8C6F19B1" # Account-level read capacity units
  service_code = "dynamodb"
  aws_region   = each.value
  value        = var.dynamodb_read_capacity_limit
}

resource "aws_servicequotas_template" "dynamodb_write_capacity" {
  for_each = var.enable_dynamodb_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-F4C74B24" # Account-level write capacity units
  service_code = "dynamodb"
  aws_region   = each.value
  value        = var.dynamodb_write_capacity_limit
}

# -----------------------------------------------------------------------------
# KINESIS SERVICE QUOTAS
# -----------------------------------------------------------------------------
# Kinesis streams have per-shard-hour pricing.

resource "aws_servicequotas_template" "kinesis_shards" {
  for_each = var.enable_kinesis_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-53A1086E" # Shards per Region
  service_code = "kinesis"
  aws_region   = each.value
  value        = var.kinesis_shard_limit
}

# -----------------------------------------------------------------------------
# CLOUDWATCH SERVICE QUOTAS
# -----------------------------------------------------------------------------
# CloudWatch logs ingestion can generate unexpected costs.

resource "aws_servicequotas_template" "cloudwatch_log_groups" {
  for_each = var.enable_cloudwatch_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-D2832119" # Log groups
  service_code = "logs"
  aws_region   = each.value
  value        = var.cloudwatch_log_group_limit
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
# BEDROCK SERVICE QUOTAS
# -----------------------------------------------------------------------------
# Bedrock has model-specific quotas. These limit tokens/requests per minute.
#
# NOTE: Only the Anthropic Claude quota is implemented. Other model families
# (Titan, Stability, Cohere, Meta) were removed because:
# 1. Their quota codes are model-specific and region-dependent
# 2. AWS Service Quota Templates don't support all Bedrock quotas
# 3. The quota codes must be verified per-region using:
#    aws service-quotas list-service-quotas --service-code bedrock --region <region>
#
# RECOMMENDATION: Use Bedrock model access policies (IAM) to restrict which
# models users can invoke, rather than relying on service quotas alone.

resource "aws_servicequotas_template" "bedrock_anthropic_tokens" {
  for_each = var.enable_bedrock_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-F5FA8D9D" # Anthropic Claude tokens per minute
  service_code = "bedrock"
  aws_region   = each.value
  value        = var.bedrock_tokens_per_minute
}

# -----------------------------------------------------------------------------
# REMOVED: Additional Bedrock model quotas (Titan, Stability, Cohere, Meta)
# -----------------------------------------------------------------------------
# These resources were removed because they used placeholder quota codes
# (L-1A2A3A4A, L-2B2B2B2B, L-3C3C3C3C, L-4D4D4D4D) that don't exist in AWS.
#
# To add quotas for other Bedrock models:
# 1. Run: aws service-quotas list-service-quotas --service-code bedrock --region us-east-1
# 2. Find the actual quota code for the specific model
# 3. Note: Not all models have adjustable quotas via Service Quota Templates
# 4. Alternative: Use IAM policies to deny access to specific models

# -----------------------------------------------------------------------------
# API GATEWAY QUOTAS
# -----------------------------------------------------------------------------
# GAP FIX: Limit API Gateway to prevent request cost explosion
# Without throttling limits, attackers could generate millions of requests
#
# NOTE: Only throttle rate is adjustable via Service Quota Templates.
# The burst limit (L-CDF5615A) cannot be adjusted via templates and was removed.
# Burst limit changes require a support case to AWS.

resource "aws_servicequotas_template" "apigateway_throttle_rate" {
  for_each = var.enable_apigateway_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-8A5B8E40" # Throttle rate (requests per second)
  service_code = "apigateway"
  aws_region   = each.value
  value        = var.apigateway_throttle_rate_limit
}

# REMOVED: apigateway_throttle_burst (L-CDF5615A)
# This quota is NOT adjustable via Service Quota Templates.
# AWS returns: "IllegalArgumentException: Quota L-CDF5615A is not adjustable"
# To change burst limits, open an AWS Support case.
