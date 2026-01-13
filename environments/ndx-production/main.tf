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

  # Automated actions - DISABLED by default for safety
  enable_automated_actions = var.enable_budget_automated_actions

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
    iam_workload_identity   = module.scp_manager.iam_workload_identity_policy_id
    restrictions            = module.scp_manager.restrictions_policy_id
  }
}

output "exempt_roles" {
  description = "Role ARN patterns exempt from SCPs"
  value       = module.scp_manager.exempt_role_arns
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
