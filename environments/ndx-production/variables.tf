variable "aws_region" {
  description = "AWS region for provider (Organizations API is global but needs a region)"
  type        = string
  default     = "us-east-1"
}

variable "namespace" {
  description = "The ISB namespace"
  type        = string
  default     = "ndx"
}

variable "managed_regions" {
  description = "AWS regions allowed for sandbox accounts"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "sandbox_ou_id" {
  description = "Organization Unit ID for the sandbox OU (e.g., ou-xxxx-xxxxxxxx)"
  type        = string
}

variable "enable_cost_avoidance" {
  description = "Whether to create cost avoidance SCP"
  type        = bool
  default     = true
}

variable "cost_avoidance_ou_id" {
  description = "OU ID to attach cost avoidance SCP (defaults to Active OU for running sandboxes)"
  type        = string
  default     = null
}

variable "allowed_ec2_instance_types" {
  description = "EC2 instance types allowed in sandboxes. Uses module default if not specified."
  type        = list(string)
  default     = null # Uses scp-manager module default
}

# =============================================================================
# SERVICE QUOTAS (24-HOUR LEASE OPTIMIZED)
# =============================================================================

variable "enable_service_quotas" {
  description = "Enable Service Quota Templates for sandbox accounts"
  type        = bool
  default     = true
}

variable "ec2_vcpu_quota" {
  description = "Maximum vCPUs for On-Demand EC2 instances (24hr: 64 vCPUs @ $0.05/hr = ~$77/day)"
  type        = number
  default     = 64
}

variable "ebs_storage_quota_tib" {
  description = "Maximum EBS storage per type (gp2/gp3) in TiB (24hr: 1 TiB @ $0.08/GB-month = ~$2.73/day)"
  type        = number
  default     = 1
}

variable "lambda_concurrency_quota" {
  description = "Maximum Lambda concurrent executions"
  type        = number
  default     = 100
}

variable "rds_instance_quota" {
  description = "Maximum RDS DB instances (24hr: 5 x db.m5.large @ $4.10/day = ~$20.50/day)"
  type        = number
  default     = 5
}

variable "rds_storage_quota_gb" {
  description = "Maximum total RDS storage in GB (24hr: 500GB @ $0.115/GB-month = ~$1.92/day)"
  type        = number
  default     = 500
}

# =============================================================================
# AWS BUDGETS (PER-ACCOUNT FROM POOL OU)
# =============================================================================
# Budgets are automatically created for each account discovered in the sandbox
# pool OU. This scales automatically as new pool accounts are added.

variable "enable_budgets" {
  description = "Enable AWS Budgets for cost tracking and alerts"
  type        = bool
  default     = true
}

variable "sandbox_pool_ou_id" {
  description = <<-EOT
    Organization Unit ID containing sandbox pool accounts.

    All ACTIVE accounts in this OU will automatically get budgets created.
    As new accounts are added to the pool, re-running terraform creates their budgets.

    Example: ou-xxxx-xxxxxxxx (e.g., the "Active" or "Pool" OU)
  EOT
  type        = string
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alert notifications. Set via TF_VAR_budget_alert_emails from GitHub secret."
  type        = list(string)
  default     = [] # Provided via GitHub Actions secret SLACK_BUDGET_ALERT_EMAIL
}

variable "daily_budget_limit" {
  description = "Daily cost budget limit in USD PER ACCOUNT"
  type        = number
  default     = 50
}

variable "monthly_budget_limit" {
  description = "Monthly cost budget limit in USD PER ACCOUNT"
  type        = number
  default     = 1000
}

variable "enable_service_budgets" {
  description = "Enable service-specific budgets (EC2, RDS, Lambda, etc.)"
  type        = bool
  default     = true
}

variable "ec2_daily_budget" {
  description = "Daily EC2 compute budget in USD (consolidated across all accounts)"
  type        = number
  default     = 100
}

variable "rds_daily_budget" {
  description = "Daily RDS budget in USD (consolidated across all accounts)"
  type        = number
  default     = 30
}

variable "lambda_daily_budget" {
  description = "Daily Lambda budget in USD (consolidated across all accounts)"
  type        = number
  default     = 50
}

variable "dynamodb_daily_budget" {
  description = "Daily DynamoDB budget in USD (consolidated across all accounts)"
  type        = number
  default     = 50
}

variable "bedrock_daily_budget" {
  description = "Daily Bedrock AI budget in USD (consolidated across all accounts)"
  type        = number
  default     = 50
}

variable "data_transfer_daily_budget" {
  description = "Daily data transfer budget in USD (consolidated across all accounts)"
  type        = number
  default     = 20
}

variable "enable_budget_automated_actions" {
  description = "Enable automated budget actions (stop EC2 at 100%). CAUTION: Will stop running instances."
  type        = bool
  default     = false
}

# =============================================================================
# COST ANOMALY DETECTION (FREE - ML-BASED)
# =============================================================================

variable "enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection (FREE service using ML to detect unusual spending)"
  type        = bool
  default     = true
}

variable "cost_anomaly_create_monitors" {
  description = "Create new anomaly monitors. Set false if account has 10 monitors (AWS limit)."
  type        = bool
  default     = false
}

variable "cost_anomaly_existing_monitor_arns" {
  description = "Existing Cost Anomaly Monitor ARNs to use when create_monitors=false"
  type        = list(string)
  default     = []
}

# =============================================================================
# DYNAMODB BILLING ENFORCER (GAP FIX)
# =============================================================================

variable "enable_dynamodb_billing_enforcer" {
  description = <<-EOT
    Enable DynamoDB billing mode enforcement.

    GAP FIX: DynamoDB On-Demand mode bypasses WCU/RCU service quotas.
    This module detects On-Demand tables and converts them to Provisioned mode.

    Without this: Attackers can create On-Demand tables with UNLIMITED request costs.
    With this: Tables are auto-converted to Provisioned with bounded capacity.
  EOT
  type        = bool
  default     = true
}

variable "dynamodb_exempt_prefixes" {
  description = "List of DynamoDB table name prefixes to exempt from billing enforcement"
  type        = list(string)
  default     = []
}

# =============================================================================
# IAM WORKLOAD IDENTITY
# =============================================================================

variable "enable_iam_workload_identity" {
  description = <<-EOT
    Enable IAM Workload Identity SCP that allows users to create IAM roles
    for workloads (EC2 instance profiles, Lambda execution roles, etc.)
    while preventing privilege escalation.

    When enabled, users CAN:
    - Create IAM roles and users
    - Attach policies to their created roles
    - Create instance profiles for EC2

    Users CANNOT:
    - Create roles matching exempt patterns (InnovationSandbox*, Admin*, etc.)
    - Modify or delete privileged admin roles
    - Pass or assume privileged roles

    IMPORTANT: The Innovation Sandbox "SecurityAndIsolationRestrictions" SCP
    must also be modified to REMOVE iam:CreateRole and iam:CreateUser from
    its deny list for users to actually create roles.
  EOT
  type        = bool
  default     = false
}
