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

  enable_cost_avoidance      = var.enable_cost_avoidance
  cost_avoidance_ou_id       = var.cost_avoidance_ou_id
  allowed_ec2_instance_types = var.allowed_ec2_instance_types

  # IAM Workload Identity - allows users to create roles for EC2/Lambda/etc.
  enable_iam_workload_identity = var.enable_iam_workload_identity

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
  ec2_gpu_vcpu_limit        = 4 # Allow limited GPU usage
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
  ebs_snapshot_limit  = 20 # Reduced - 100 excessive for 24hr lease

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

  # DynamoDB quotas - CRITICAL: limit capacity to prevent cost explosion
  enable_dynamodb_quotas        = var.enable_service_quotas
  dynamodb_table_limit          = 50
  dynamodb_read_capacity_limit  = 1000 # ~$3/day max (default 80,000 = $250/day!)
  dynamodb_write_capacity_limit = 1000 # ~$16/day max (default 80,000 = $1,248/day!)

  # Kinesis - 0 shards (blocked in SCP)
  enable_kinesis_quotas = var.enable_service_quotas
  kinesis_shard_limit   = 0

  # CloudWatch - reasonable log group limit
  enable_cloudwatch_quotas   = var.enable_service_quotas
  cloudwatch_log_group_limit = 50

  # Bedrock quotas - limit token usage to control AI costs
  enable_bedrock_quotas     = var.enable_service_quotas
  bedrock_tokens_per_minute = 5000 # ~$72/day max at avg pricing

  # Enable template association for automatic application
  enable_template_association = var.enable_service_quotas

  tags = {
    Component = "Service-Quotas"
  }
}

# =============================================================================
# DYNAMIC ACCOUNT DISCOVERY FROM SANDBOX POOL OU
# =============================================================================
# Automatically discovers all accounts in the sandbox pool OU.
# This enables per-account budget creation without manual account ID management.
#
# As new pool accounts are created, re-running terraform will automatically
# create budgets for them.

data "aws_organizations_organizational_unit_descendant_accounts" "sandbox_pool" {
  count     = var.enable_budgets ? 1 : 0
  parent_id = var.sandbox_pool_ou_id
}

locals {
  # Filter to only ACTIVE accounts (exclude suspended/closed)
  sandbox_account_ids = var.enable_budgets ? [
    for account in data.aws_organizations_organizational_unit_descendant_accounts.sandbox_pool[0].accounts :
    account.id if account.status == "ACTIVE"
  ] : []

  # Count for logging/output
  sandbox_account_count = length(local.sandbox_account_ids)
}

# =============================================================================
# AWS BUDGETS (PER-ACCOUNT)
# =============================================================================
# Creates a separate budget for EACH sandbox account discovered in the pool OU.
# This ensures one account can't consume another's budget allocation.

module "budgets" {
  source = "../../modules/budgets-manager"
  count  = var.enable_budgets ? 1 : 0

  namespace      = var.namespace
  primary_region = var.managed_regions[0]

  # Per-account budgets - each account gets its own $X/day limit
  sandbox_account_ids = local.sandbox_account_ids

  # SNS notifications
  create_sns_topic = true
  alert_emails     = var.budget_alert_emails

  # Daily budget per account
  daily_budget_limit = var.daily_budget_limit

  # Monthly budget per account
  create_monthly_budget = true
  monthly_budget_limit  = var.monthly_budget_limit

  # Service-specific budgets (consolidated across all accounts for visibility)
  create_service_budgets    = var.enable_service_budgets
  ec2_daily_limit           = var.ec2_daily_budget
  rds_daily_limit           = var.rds_daily_budget
  lambda_daily_limit        = var.lambda_daily_budget
  dynamodb_daily_limit      = var.dynamodb_daily_budget
  bedrock_daily_limit       = var.bedrock_daily_budget
  data_transfer_daily_limit = var.data_transfer_daily_budget

  # Automated actions - always enabled (stops EC2 at 100% budget)
  enable_automated_actions = true

  tags = {
    Component = "Budget-Guardrails"
  }
}

# =============================================================================
# COST ANOMALY DETECTION (ML-BASED - FREE SERVICE)
# =============================================================================
# Layer 4 of defense in depth - uses machine learning to detect unusual
# spending patterns. This is a FREE service.

module "cost_anomaly_detection" {
  source = "../../modules/cost-anomaly-detection"
  count  = var.enable_cost_anomaly_detection ? 1 : 0

  namespace = var.namespace

  # Use existing budget alert emails for consistency
  create_sns_topic = true
  alert_emails     = var.budget_alert_emails

  # Monitor linked sandbox accounts
  monitor_linked_accounts = true

  # Alert configuration - tuned for 24-hour sandbox leases
  alert_frequency        = "DAILY"
  alert_threshold_amount = 10 # Alert on anomalies >= $10

  # High-priority immediate alerts for large anomalies
  enable_high_priority_alerts    = true
  high_priority_threshold_amount = var.daily_budget_limit # Alert immediately if anomaly >= daily budget

  tags = {
    Component = "Cost-Anomaly-Detection"
  }
}

# =============================================================================
# DYNAMODB BILLING MODE ENFORCER (GAP FIX)
# =============================================================================
# Critical gap closure: DynamoDB On-Demand mode bypasses WCU/RCU quotas.
# This module uses EventBridge + Lambda to detect On-Demand tables and DELETE them.
# Broadcasts event to EventBridge for downstream processing.

module "dynamodb_billing_enforcer" {
  source = "../../modules/dynamodb-billing-enforcer"
  count  = var.enable_dynamodb_billing_enforcer ? 1 : 0

  namespace = var.namespace

  # Send alerts to same topic as budgets
  sns_topic_arn = var.enable_budgets ? module.budgets[0].sns_topic_arn : null

  # Exempt infrastructure tables if any
  exempt_table_prefixes = var.dynamodb_exempt_prefixes

  tags = {
    Component = "DynamoDB-Billing-Enforcer"
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
    iam_workload_identity   = module.scp_manager.iam_workload_identity_policy_id
    restrictions            = module.scp_manager.restrictions_policy_id
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

# -----------------------------------------------------------------------------
# BUDGET OUTPUTS
# -----------------------------------------------------------------------------

output "discovered_sandbox_accounts" {
  description = "List of sandbox account IDs discovered from the pool OU"
  value = var.enable_budgets ? {
    count       = local.sandbox_account_count
    account_ids = local.sandbox_account_ids
  } : null
}

output "budget_sns_topic_arn" {
  description = "SNS topic ARN for budget alerts"
  value       = var.enable_budgets ? module.budgets[0].sns_topic_arn : null
}

output "per_account_daily_budgets" {
  description = "Map of account IDs to their daily budget names"
  value       = var.enable_budgets ? module.budgets[0].daily_budget_names_per_account : null
}

output "budget_summary" {
  description = "Summary of budget configuration"
  value = var.enable_budgets ? {
    mode                = "per-account"
    accounts_discovered = local.sandbox_account_count
    daily_limit         = "$${var.daily_budget_limit}/day per account"
    monthly_limit       = "$${var.monthly_budget_limit}/month per account"
    service_budgets     = var.enable_service_budgets ? "enabled" : "disabled"
    source_ou           = var.sandbox_pool_ou_id
  } : null
}

output "cost_anomaly_detection_summary" {
  description = "Summary of cost anomaly detection configuration"
  value       = var.enable_cost_anomaly_detection ? module.cost_anomaly_detection[0].anomaly_detection_summary : null
}

output "dynamodb_billing_enforcer_summary" {
  description = "Summary of DynamoDB billing enforcement"
  value       = var.enable_dynamodb_billing_enforcer ? module.dynamodb_billing_enforcer[0].enforcement_summary : null
}
