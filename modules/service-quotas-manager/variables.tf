# =============================================================================
# SERVICE QUOTAS MANAGER - VARIABLES
# =============================================================================
# These quotas are designed for 24-HOUR SANDBOX LEASES.
#
# COST CALCULATION BASIS:
# - Each sandbox account is leased for max 24 hours
# - Quotas should limit MAXIMUM POSSIBLE SPEND within that window
# - Default values assume a reasonable daily budget of ~$100-500
#
# FORMULA FOR LIMITS:
#   max_resources = target_daily_budget / (hourly_cost * 24)
#
# Example: EC2 vCPUs
#   - m5.xlarge = 4 vCPUs @ $0.192/hr = $4.61/day per instance
#   - 64 vCPUs = 16 x m5.xlarge = ~$74/day (safe for experimentation)
#   - Or 64 t3.micro = ~$9/day (minimal spend)
# =============================================================================

# -----------------------------------------------------------------------------
# GENERAL CONFIGURATION
# -----------------------------------------------------------------------------

variable "primary_region" {
  description = "Primary AWS region for quotas (e.g., us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for quotas (e.g., us-west-2). Set to null to disable."
  type        = string
  default     = "us-west-2"
}

variable "enable_template_association" {
  description = "Enable Service Quota Template association with the organization"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# EC2 QUOTAS
# -----------------------------------------------------------------------------
# EC2 is typically the largest spend category. vCPU limits are the most
# effective control as they limit total compute regardless of instance count.

variable "enable_ec2_quotas" {
  description = "Enable EC2 service quota limits"
  type        = bool
  default     = true
}

variable "ec2_on_demand_vcpu_limit" {
  description = <<-EOT
    Maximum vCPUs for On-Demand Standard instances (A, C, D, H, I, M, R, T, Z families).

    24-HOUR COST ANALYSIS:
    - 64 vCPUs @ avg $0.05/vCPU-hr = $77/day max compute spend
    - Allows: 64 t3.micro, or 16 m5.xlarge, or 8 m5.2xlarge
    - Blocks: 65+ vCPU configurations
  EOT
  type        = number
  default     = 64
}

variable "ec2_spot_vcpu_limit" {
  description = <<-EOT
    Maximum vCPUs for Spot instances (all standard families).

    24-HOUR COST ANALYSIS:
    - Spot is ~70% cheaper than On-Demand
    - 64 vCPUs @ avg $0.015/vCPU-hr = $23/day max
    - Set equal to on-demand for flexibility
  EOT
  type        = number
  default     = 64
}

variable "ec2_gpu_vcpu_limit" {
  description = <<-EOT
    Maximum vCPUs for G and VT (GPU/Graphics) instances.

    24-HOUR COST ANALYSIS:
    - g4dn.xlarge = 4 vCPUs @ $0.526/hr = $12.62/day
    - g5.xlarge = 4 vCPUs @ $1.006/hr = $24.14/day
    - DEFAULT: 0 (completely blocked - also blocked in SCP)
  EOT
  type        = number
  default     = 0
}

variable "ec2_p_instance_vcpu_limit" {
  description = <<-EOT
    Maximum vCPUs for P instances (ML/GPU training).

    24-HOUR COST ANALYSIS:
    - p3.2xlarge = 8 vCPUs @ $3.06/hr = $73.44/day
    - p4d.24xlarge = 96 vCPUs @ $32.77/hr = $786.48/day
    - DEFAULT: 0 (completely blocked - also blocked in SCP)
  EOT
  type        = number
  default     = 0
}

variable "ec2_inf_vcpu_limit" {
  description = <<-EOT
    Maximum vCPUs for Inf (Inferentia) instances.

    24-HOUR COST ANALYSIS:
    - inf1.xlarge = 4 vCPUs @ $0.228/hr = $5.47/day
    - DEFAULT: 0 (completely blocked - also blocked in SCP)
  EOT
  type        = number
  default     = 0
}

variable "ec2_dl_vcpu_limit" {
  description = "Maximum vCPUs for DL (Deep Learning) instances. DEFAULT: 0 (blocked)"
  type        = number
  default     = 0
}

variable "ec2_trn_vcpu_limit" {
  description = "Maximum vCPUs for Trn (Trainium) instances. DEFAULT: 0 (blocked)"
  type        = number
  default     = 0
}

variable "ec2_high_mem_vcpu_limit" {
  description = <<-EOT
    Maximum vCPUs for High Memory instances (u-* family with 6TB-24TB RAM).

    24-HOUR COST ANALYSIS:
    - u-6tb1.metal = 448 vCPUs @ $27.30/hr = $655.20/day
    - DEFAULT: 0 (completely blocked - also blocked in SCP)
  EOT
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# EBS QUOTAS
# -----------------------------------------------------------------------------
# EBS storage persists and accumulates. Limiting total storage prevents
# runaway storage costs.

variable "enable_ebs_quotas" {
  description = "Enable EBS service quota limits"
  type        = bool
  default     = true
}

variable "ebs_gp3_storage_tib" {
  description = <<-EOT
    Maximum gp3 storage in TiB.

    24-HOUR COST ANALYSIS:
    - gp3 @ $0.08/GB-month = ~$0.0027/GB-day
    - 1 TiB (1024 GB) = ~$2.76/day
    - Allows reasonable development storage
  EOT
  type        = number
  default     = 1
}

variable "ebs_gp2_storage_tib" {
  description = <<-EOT
    Maximum gp2 storage in TiB.

    24-HOUR COST ANALYSIS:
    - gp2 @ $0.10/GB-month = ~$0.0033/GB-day
    - 1 TiB (1024 GB) = ~$3.38/day
  EOT
  type        = number
  default     = 1
}

variable "ebs_io1_iops_limit" {
  description = <<-EOT
    Maximum Provisioned IOPS for io1 volumes.

    24-HOUR COST ANALYSIS:
    - io1 IOPS @ $0.065/IOPS-month = ~$0.0022/IOPS-day
    - DEFAULT: 0 (completely blocked - also blocked in SCP)
  EOT
  type        = number
  default     = 0
}

variable "ebs_io2_iops_limit" {
  description = "Maximum Provisioned IOPS for io2 volumes. DEFAULT: 0 (blocked)"
  type        = number
  default     = 0
}

variable "ebs_snapshot_limit" {
  description = <<-EOT
    Maximum number of EBS snapshots.

    24-HOUR COST ANALYSIS:
    - Snapshots @ $0.05/GB-month = ~$0.0017/GB-day
    - 100 snapshots of 10GB each = 1TB = ~$1.67/day
    - Primary cost is storage, not count
  EOT
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# LAMBDA QUOTAS
# -----------------------------------------------------------------------------

variable "enable_lambda_quotas" {
  description = "Enable Lambda service quota limits"
  type        = bool
  default     = true
}

variable "lambda_concurrent_executions" {
  description = <<-EOT
    Maximum concurrent Lambda executions.

    24-HOUR COST ANALYSIS:
    - Lambda @ $0.0000166667/GB-second
    - 100 concurrent @ 1GB @ 1sec each, running constantly:
      100 * 60 * 60 * 24 = 8.64M invocations = ~$144/day (extreme case)
    - More realistic: 100 concurrent handles normal API loads
  EOT
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# VPC QUOTAS
# -----------------------------------------------------------------------------
# NAT Gateways have per-hour costs and per-GB data processing.

variable "enable_vpc_quotas" {
  description = "Enable VPC service quota limits"
  type        = bool
  default     = true
}

variable "vpc_limit" {
  description = <<-EOT
    Maximum VPCs per region.

    24-HOUR COST ANALYSIS:
    - VPCs are free, but associated resources (NAT, EIP) cost
    - 5 VPCs is enough for most experiments
  EOT
  type        = number
  default     = 5
}

variable "nat_gateway_per_az_limit" {
  description = <<-EOT
    Maximum NAT Gateways per Availability Zone.

    24-HOUR COST ANALYSIS:
    - NAT Gateway @ $0.045/hr = $1.08/day per gateway
    - Plus $0.045/GB data processed
    - 2 per AZ, 3 AZs = 6 gateways = $6.48/day (minimum)
  EOT
  type        = number
  default     = 2
}

variable "elastic_ip_limit" {
  description = <<-EOT
    Maximum Elastic IPs.

    24-HOUR COST ANALYSIS:
    - Attached EIP: Free
    - Unattached EIP: $0.005/hr = $0.12/day
    - 5 EIPs = reasonable for development
  EOT
  type        = number
  default     = 5
}

# -----------------------------------------------------------------------------
# RDS QUOTAS
# -----------------------------------------------------------------------------

variable "enable_rds_quotas" {
  description = "Enable RDS service quota limits"
  type        = bool
  default     = true
}

variable "rds_instance_limit" {
  description = <<-EOT
    Maximum RDS DB instances.

    24-HOUR COST ANALYSIS:
    - db.t3.medium @ $0.068/hr = $1.63/day
    - db.m5.large @ $0.171/hr = $4.10/day
    - 5 instances x $4.10 = $20.50/day max (reasonable)
  EOT
  type        = number
  default     = 5
}

variable "rds_total_storage_gb" {
  description = <<-EOT
    Maximum total RDS storage across all instances (GB).

    24-HOUR COST ANALYSIS:
    - gp2 storage @ $0.115/GB-month = ~$0.0038/GB-day
    - 500 GB = ~$1.92/day
  EOT
  type        = number
  default     = 500
}

variable "rds_read_replicas_per_source" {
  description = <<-EOT
    Maximum read replicas per source DB.

    24-HOUR COST ANALYSIS:
    - Each replica = additional instance cost
    - DEFAULT: 0 (also blocked in SCP)
  EOT
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# ELASTICACHE QUOTAS
# -----------------------------------------------------------------------------

variable "enable_elasticache_quotas" {
  description = "Enable ElastiCache service quota limits"
  type        = bool
  default     = true
}

variable "elasticache_node_limit" {
  description = <<-EOT
    Maximum ElastiCache nodes per region.

    24-HOUR COST ANALYSIS:
    - cache.t3.medium @ $0.068/hr = $1.63/day
    - cache.m5.large @ $0.172/hr = $4.13/day
    - 10 nodes x $4.13 = $41.30/day max
  EOT
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# EKS QUOTAS
# -----------------------------------------------------------------------------

variable "enable_eks_quotas" {
  description = "Enable EKS service quota limits"
  type        = bool
  default     = true
}

variable "eks_cluster_limit" {
  description = <<-EOT
    Maximum EKS clusters per region.

    24-HOUR COST ANALYSIS:
    - EKS control plane @ $0.10/hr = $2.40/day per cluster
    - Plus node costs (covered by EC2 quotas)
    - 2 clusters is sufficient for most experiments
  EOT
  type        = number
  default     = 2
}

# -----------------------------------------------------------------------------
# LOAD BALANCER QUOTAS
# -----------------------------------------------------------------------------

variable "enable_elb_quotas" {
  description = "Enable Elastic Load Balancing service quota limits"
  type        = bool
  default     = true
}

variable "alb_limit" {
  description = <<-EOT
    Maximum Application Load Balancers per region.

    24-HOUR COST ANALYSIS:
    - ALB @ $0.0225/hr = $0.54/day per ALB
    - Plus $0.008/LCU-hour
    - 5 ALBs = $2.70/day (minimum)
  EOT
  type        = number
  default     = 5
}

variable "nlb_limit" {
  description = <<-EOT
    Maximum Network Load Balancers per region.

    24-HOUR COST ANALYSIS:
    - NLB @ $0.0225/hr = $0.54/day per NLB
    - 5 NLBs = $2.70/day (minimum)
  EOT
  type        = number
  default     = 5
}

# -----------------------------------------------------------------------------
# DYNAMODB QUOTAS
# -----------------------------------------------------------------------------

variable "enable_dynamodb_quotas" {
  description = "Enable DynamoDB service quota limits"
  type        = bool
  default     = true
}

variable "dynamodb_table_limit" {
  description = <<-EOT
    Maximum number of DynamoDB tables.

    NOTE: DynamoDB capacity (RCU/WCU) is not directly limited by service quotas.
    Cost depends on provisioned capacity or on-demand usage.
    Consider using AWS Budgets with actions for DynamoDB cost control.
  EOT
  type        = number
  default     = 50
}

# -----------------------------------------------------------------------------
# KINESIS QUOTAS
# -----------------------------------------------------------------------------

variable "enable_kinesis_quotas" {
  description = "Enable Kinesis service quota limits"
  type        = bool
  default     = true
}

variable "kinesis_shard_limit" {
  description = <<-EOT
    Maximum Kinesis Data Streams shards per region.

    24-HOUR COST ANALYSIS:
    - $0.015/shard-hour = $0.36/shard-day
    - DEFAULT: 0 (Kinesis is blocked in SCP)
  EOT
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# CLOUDWATCH QUOTAS
# -----------------------------------------------------------------------------

variable "enable_cloudwatch_quotas" {
  description = "Enable CloudWatch service quota limits"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_limit" {
  description = <<-EOT
    Maximum CloudWatch Log groups.

    24-HOUR COST ANALYSIS:
    - Log groups are free; cost is from ingestion ($0.50/GB)
    - 50 log groups is reasonable limit to prevent sprawl
  EOT
  type        = number
  default     = 50
}

# -----------------------------------------------------------------------------
# TAGS
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}
