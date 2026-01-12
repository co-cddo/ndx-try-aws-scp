terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket         = "ndx-terraform-state"
  #   key            = "scp-overrides/terraform.tfstate"
  #   region         = "eu-west-2"
  #   encrypt        = true
  #   dynamodb_table = "ndx-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  # Assume role for Organizations access (if needed)
  # assume_role {
  #   role_arn = "arn:aws:iam::${var.management_account_id}:role/TerraformSCPManager"
  # }

  default_tags {
    tags = {
      Project     = "NDX"
      ManagedBy   = "Terraform"
      Environment = "production"
      Repository  = "terraform-scp-overrides"
    }
  }
}

module "scp_manager" {
  source = "../../modules/scp-manager"

  namespace       = var.namespace
  managed_regions = var.managed_regions
  sandbox_ou_id   = var.sandbox_ou_id

  cost_avoidance_ou_id       = var.cost_avoidance_ou_id
  allowed_ec2_instance_types = var.allowed_ec2_instance_types

  tags = {
    Component = "SCP-Overrides"
  }
}

# =============================================================================
# SERVICE QUOTAS (24-HOUR LEASE OPTIMIZED)
# =============================================================================
# Service Quotas complement SCPs by limiting the NUMBER of resources.
# Quotas are designed for 24-hour sandbox leases with a target daily budget.
# Uses Service Quota Templates for automatic application to new accounts.

module "service_quotas" {
  source = "../../modules/service-quotas-manager"

  # Regions matching the SCP limit_regions configuration
  primary_region   = var.managed_regions[0] # us-east-1
  secondary_region = length(var.managed_regions) > 1 ? var.managed_regions[1] : null

  # EC2 quotas - 64 vCPUs allows reasonable compute, ~$77/day max
  enable_ec2_quotas         = var.enable_service_quotas
  ec2_on_demand_vcpu_limit  = var.ec2_vcpu_quota
  ec2_spot_vcpu_limit       = var.ec2_vcpu_quota
  ec2_gpu_vcpu_limit        = 0 # Blocked - also in SCP
  ec2_p_instance_vcpu_limit = 0 # Blocked - also in SCP
  ec2_inf_vcpu_limit        = 0 # Blocked - also in SCP
  ec2_dl_vcpu_limit         = 0 # Blocked - also in SCP
  ec2_trn_vcpu_limit        = 0 # Blocked - also in SCP
  ec2_high_mem_vcpu_limit   = 0 # Blocked - also in SCP

  # EBS quotas - 2 TiB total, ~$6/day
  enable_ebs_quotas   = var.enable_service_quotas
  ebs_gp3_storage_tib = var.ebs_storage_quota_tib
  ebs_gp2_storage_tib = var.ebs_storage_quota_tib
  ebs_io1_iops_limit  = 0 # Blocked - also in SCP
  ebs_io2_iops_limit  = 0 # Blocked - also in SCP
  ebs_snapshot_limit  = 100

  # Lambda quotas - 100 concurrent executions
  enable_lambda_quotas         = var.enable_service_quotas
  lambda_concurrent_executions = var.lambda_concurrency_quota

  # VPC quotas - reasonable limits for experimentation
  enable_vpc_quotas        = var.enable_service_quotas
  vpc_limit                = 5
  nat_gateway_per_az_limit = 2
  elastic_ip_limit         = 5

  # RDS quotas - 5 instances, 500GB total
  enable_rds_quotas            = var.enable_service_quotas
  rds_instance_limit           = var.rds_instance_quota
  rds_total_storage_gb         = var.rds_storage_quota_gb
  rds_read_replicas_per_source = 0 # Blocked - also in SCP

  # ElastiCache quotas - 10 nodes max
  enable_elasticache_quotas = var.enable_service_quotas
  elasticache_node_limit    = 10

  # EKS quotas - 2 clusters max
  enable_eks_quotas = var.enable_service_quotas
  eks_cluster_limit = 2

  # Load balancer quotas
  enable_elb_quotas = var.enable_service_quotas
  alb_limit         = 5
  nlb_limit         = 5

  # DynamoDB quotas - table count only (capacity not limitable via quotas)
  enable_dynamodb_quotas = var.enable_service_quotas
  dynamodb_table_limit   = 50

  # Kinesis - 0 shards (blocked in SCP)
  enable_kinesis_quotas = var.enable_service_quotas
  kinesis_shard_limit   = 0

  # CloudWatch - reasonable log group limit
  enable_cloudwatch_quotas   = var.enable_service_quotas
  cloudwatch_log_group_limit = 50

  # Enable template association for automatic application
  enable_template_association = var.enable_service_quotas

  tags = {
    Component = "Service-Quotas"
  }
}

# =============================================================================
# AWS BUDGETS (24-HOUR LEASE COST GUARDRAILS)
# =============================================================================
# Budgets are the final layer of defense - they track ACTUAL SPEND
# and can trigger automated actions when thresholds are exceeded.
#
# Defense in Depth:
#   Layer 1: SCPs - What actions are allowed
#   Layer 2: Service Quotas - How many resources can exist
#   Layer 3: Budgets - How much money can be spent

module "budgets" {
  source = "../../modules/budgets-manager"

  namespace      = var.namespace
  primary_region = var.managed_regions[0]

  # SNS notifications
  create_sns_topic = var.enable_budgets
  alert_emails     = var.budget_alert_emails

  # Daily budget - matches existing ClickOps budget
  daily_budget_name  = var.daily_budget_name
  daily_budget_limit = var.daily_budget_limit

  # Monthly aggregate budget - matches existing ClickOps budget
  create_monthly_budget = var.enable_budgets
  monthly_budget_name   = var.monthly_budget_name
  monthly_budget_limit  = var.monthly_budget_limit

  # Service-specific budgets catch runaway spending
  create_service_budgets    = var.enable_budgets
  ec2_daily_limit           = var.ec2_daily_budget
  rds_daily_limit           = var.rds_daily_budget
  lambda_daily_limit        = var.lambda_daily_budget
  dynamodb_daily_limit      = var.dynamodb_daily_budget
  bedrock_daily_limit       = var.bedrock_daily_budget
  data_transfer_daily_limit = var.data_transfer_daily_budget

  # Automated actions - DISABLED by default for safety
  # When enabled, will stop EC2 instances at 100% budget
  enable_automated_actions = var.enable_budget_automated_actions

  # Filter to sandbox accounts (optional)
  sandbox_account_ids = var.sandbox_account_ids

  tags = {
    Component = "Budget-Guardrails"
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "scp_policy_ids" {
  description = "Map of SCP names to their policy IDs"
  value = {
    nuke_supported_services = module.scp_manager.nuke_supported_services_policy_id
    limit_regions           = module.scp_manager.limit_regions_policy_id
    cost_avoidance          = module.scp_manager.cost_avoidance_policy_id
  }
}

output "exempt_roles" {
  description = "Role ARN patterns exempt from SCPs"
  value       = module.scp_manager.exempt_role_arns
}

output "service_quotas_summary" {
  description = "Summary of service quota limits"
  value       = var.enable_service_quotas ? module.service_quotas.quota_summary : null
}

output "estimated_max_daily_cost" {
  description = "Estimated maximum daily cost based on quotas"
  value       = var.enable_service_quotas ? module.service_quotas.estimated_max_daily_cost : "Service quotas disabled"
}

output "budget_limits_summary" {
  description = "Summary of budget limits and thresholds"
  value       = var.enable_budgets ? module.budgets.budget_limits_summary : null
}

output "budget_sns_topic_arn" {
  description = "SNS topic ARN for budget alerts"
  value       = var.enable_budgets ? module.budgets.sns_topic_arn : null
}

output "cost_defense_summary" {
  description = "Summary of all cost defense layers"
  value = {
    layer_1_scps = {
      status = "Always enabled"
      controls = [
        "Instance type allowlist",
        "GPU/accelerated instances blocked",
        "EBS volume type/size limits",
        "RDS instance class/Multi-AZ/IOPS limits",
        "ElastiCache node type limits",
        "Auto Scaling Group size limits",
        "EKS nodegroup size limits",
        "Expensive services blocked"
      ]
    }
    layer_2_quotas = {
      status            = var.enable_service_quotas ? "Enabled" : "Disabled"
      max_ec2_vcpus     = var.enable_service_quotas ? var.ec2_vcpu_quota : "N/A"
      max_ebs_storage   = var.enable_service_quotas ? "${var.ebs_storage_quota_tib * 2} TiB" : "N/A"
      max_rds_instances = var.enable_service_quotas ? var.rds_instance_quota : "N/A"
    }
    layer_3_budgets = {
      status            = var.enable_budgets ? "Enabled" : "Disabled"
      daily_limit       = var.enable_budgets ? "$${var.daily_budget_limit}/day" : "N/A"
      monthly_limit     = var.enable_budgets ? "$${var.monthly_budget_limit}/month" : "N/A"
      automated_actions = var.enable_budget_automated_actions ? "Enabled" : "Disabled"
    }
  }
}
