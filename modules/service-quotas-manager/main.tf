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


# DL instances (Deep Learning) - set to 0 to completely block
resource "aws_servicequotas_template" "ec2_dl_vcpus" {
  for_each = var.enable_ec2_quotas ? toset(var.regions) : toset([])

  quota_code   = "L-6E869C2A" # Running On-Demand DL instances
  service_code = "ec2"
  aws_region   = each.value
  value        = var.ec2_dl_vcpu_limit
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
