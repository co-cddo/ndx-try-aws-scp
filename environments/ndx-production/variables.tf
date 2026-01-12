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

variable "cost_avoidance_ou_id" {
  description = "OU ID to attach cost avoidance SCP (defaults to Active OU for running sandboxes)"
  type        = string
  default     = null
}

variable "allowed_ec2_instance_types" {
  description = "EC2 instance types allowed in sandboxes"
  type        = list(string)
  default = [
    "t2.micro",
    "t2.small",
    "t2.medium",
    "t3.micro",
    "t3.small",
    "t3.medium",
    "t3.large",
    "t3a.micro",
    "t3a.small",
    "t3a.medium",
    "t3a.large",
    "m5.large",
    "m5.xlarge",
    "m6i.large",
    "m6i.xlarge"
  ]
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
# AWS BUDGETS (FINAL COST DEFENSE LAYER)
# =============================================================================

variable "enable_budgets" {
  description = "Enable AWS Budgets for cost tracking and alerts"
  type        = bool
  default     = true
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alert notifications (preserving existing subscribers)"
  type        = list(string)
  default = [
    "chris.Nesbitt-Smith@digital.cabinet-office.gov.uk",
    "ndx-aaaaqa6ovbj5owumuw4jkzc44m@gds.slack.com",
    "ndx@dsit.gov.uk"
  ]
}

variable "daily_budget_name" {
  description = "Name of the daily budget (matches existing ClickOps budget)"
  type        = string
  default     = "NDX Try usage daily"
}

variable "daily_budget_limit" {
  description = "Daily cost budget limit in USD (matches existing)"
  type        = number
  default     = 50
}

variable "monthly_budget_name" {
  description = "Name of the monthly budget (matches existing ClickOps budget)"
  type        = string
  default     = "NDX Try budget"
}

variable "monthly_budget_limit" {
  description = "Monthly aggregate budget limit in USD (matches existing)"
  type        = number
  default     = 1000
}

variable "ec2_daily_budget" {
  description = "Daily EC2 compute budget in USD"
  type        = number
  default     = 100
}

variable "rds_daily_budget" {
  description = "Daily RDS budget in USD"
  type        = number
  default     = 30
}

variable "lambda_daily_budget" {
  description = "Daily Lambda budget in USD"
  type        = number
  default     = 50
}

variable "dynamodb_daily_budget" {
  description = "Daily DynamoDB budget in USD (critical - not controllable via SCP/quotas)"
  type        = number
  default     = 50
}

variable "bedrock_daily_budget" {
  description = "Daily Bedrock AI budget in USD"
  type        = number
  default     = 50
}

variable "data_transfer_daily_budget" {
  description = "Daily data transfer budget in USD"
  type        = number
  default     = 20
}

variable "enable_budget_automated_actions" {
  description = "Enable automated budget actions (stop EC2 at 100%). CAUTION: Will stop running instances."
  type        = bool
  default     = false
}

variable "sandbox_account_ids" {
  description = "List of sandbox account IDs to filter budgets (null = all linked accounts)"
  type        = list(string)
  default     = null
}

# =============================================================================
# COST ANOMALY DETECTION (FREE - ML-BASED)
# =============================================================================

variable "enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection (FREE service using ML to detect unusual spending)"
  type        = bool
  default     = true
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
