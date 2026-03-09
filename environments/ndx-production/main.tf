terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

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
  allow_rds_multi_az         = true

  # IAM Workload Identity - allows users to create roles for EC2/Lambda/etc.
  enable_iam_workload_identity = var.enable_iam_workload_identity

  tags = {
    Component = "SCP-Overrides"
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

  sns_topic_arn = var.ou_metrics_sns_topic_arn

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


# =============================================================================
# OU METRICS CLOUDWATCH ALARMS
# =============================================================================
# Monitors account pool health metrics published by the OU metrics Lambda.
# See: https://github.com/co-cddo/innovation-sandbox-on-aws-ou-metrics

module "ou_metrics_alarms" {
  source = "../../modules/ou-metrics-alarms"
  count  = var.enable_ou_metrics_alarms ? 1 : 0

  namespace = var.namespace

  sns_topic_arn = var.ou_metrics_sns_topic_arn

  # Thresholds
  available_accounts_threshold = var.available_accounts_threshold

  tags = {
    Component = "OU-Metrics-Alarms"
  }
}

output "dynamodb_billing_enforcer_summary" {
  description = "Summary of DynamoDB billing enforcement"
  value       = var.enable_dynamodb_billing_enforcer ? module.dynamodb_billing_enforcer[0].enforcement_summary : null
}

output "ou_metrics_alarms_summary" {
  description = "Summary of OU metrics alarm configuration"
  value       = var.enable_ou_metrics_alarms ? module.ou_metrics_alarms[0].alarm_summary : null
}
