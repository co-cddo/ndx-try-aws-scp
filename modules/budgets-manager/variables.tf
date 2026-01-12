# =============================================================================
# AWS BUDGETS MANAGER - VARIABLES
# =============================================================================
# Budget limits designed for 24-HOUR SANDBOX LEASES.
#
# DEFENSE IN DEPTH:
#   Layer 1: SCPs - What actions are allowed
#   Layer 2: Service Quotas - How many resources can exist
#   Layer 3: Budgets - How much money can be spent
#
# BUDGET CALCULATION:
# Based on Service Quota defaults and worst-case spending scenarios:
#   - EC2: 64 vCPUs @ $0.05/vCPU-hr = $77/day
#   - EBS: 2 TiB @ $3/day = $6/day
#   - RDS: 5 instances @ $4/day = $20/day
#   - ElastiCache: 10 nodes @ $4/day = $40/day
#   - Lambda: 100 concurrent @ extreme = $50/day
#   - Bedrock: Variable (10-50$/day typical)
#   - Data Transfer: Variable (~$10/day)
#   - Other services: ~$50/day buffer
#
# TOTAL ESTIMATED MAX: ~$250-300/day per sandbox
# Default daily limit: $200 (triggers at 80% to alert before max)
# =============================================================================

# -----------------------------------------------------------------------------
# GENERAL CONFIGURATION
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "The ISB namespace (e.g., 'ndx')"
  type        = string
  default     = "ndx"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "sandbox_account_ids" {
  description = <<-EOT
    List of sandbox account IDs to filter budgets.
    If null, budgets apply to all linked accounts.

    For Innovation Sandbox, you may want to dynamically get these
    from the Active OU or pass them as a variable.
  EOT
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# SNS NOTIFICATION CONFIGURATION
# -----------------------------------------------------------------------------

variable "create_sns_topic" {
  description = "Create a new SNS topic for budget alerts"
  type        = bool
  default     = true
}

variable "sns_topic_arns" {
  description = "Existing SNS topic ARNs for budget alerts (if not creating new)"
  type        = list(string)
  default     = []
}

variable "alert_email" {
  description = "Email address for direct budget alert subscriptions"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# AUTOMATED ACTIONS
# -----------------------------------------------------------------------------

variable "enable_automated_actions" {
  description = <<-EOT
    Enable automated budget actions (stop EC2 instances when budget exceeded).

    CAUTION: This will automatically stop running instances when budget
    thresholds are exceeded. Ensure this behavior is acceptable.
  EOT
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# DAILY BUDGET LIMITS
# -----------------------------------------------------------------------------

variable "daily_budget_limit" {
  description = <<-EOT
    Daily cost budget limit in USD.

    24-HOUR CALCULATION:
    Based on Service Quota limits, maximum theoretical daily spend is ~$250-300.
    Setting to $200 with 80% alert threshold triggers at $160, providing
    ~$40-90 buffer before hitting theoretical max.
  EOT
  type        = number
  default     = 200
}

# -----------------------------------------------------------------------------
# MONTHLY BUDGET
# -----------------------------------------------------------------------------

variable "create_monthly_budget" {
  description = "Create a monthly aggregate budget"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = <<-EOT
    Monthly cost budget limit in USD.

    CALCULATION:
    If each sandbox lease is 24 hours and we expect average utilization:
    - ~30 sandbox-days per month
    - $200/day max = $6,000/month theoretical max
    - Setting to $5,000 provides some buffer
  EOT
  type        = number
  default     = 5000
}

# -----------------------------------------------------------------------------
# SERVICE-SPECIFIC BUDGETS
# -----------------------------------------------------------------------------

variable "create_service_budgets" {
  description = "Create service-specific daily budgets"
  type        = bool
  default     = true
}

variable "ec2_daily_limit" {
  description = <<-EOT
    Daily EC2 compute budget limit in USD.

    CALCULATION:
    - 64 vCPUs @ $0.05/vCPU-hr * 24 hours = $76.80/day
    - Setting to $100 provides buffer for variability
  EOT
  type        = number
  default     = 100
}

variable "rds_daily_limit" {
  description = <<-EOT
    Daily RDS budget limit in USD.

    CALCULATION:
    - 5 x db.m5.large @ $0.171/hr * 24 = $20.52/day
    - Plus storage: 500GB @ $0.115/GB-month / 30 = $1.92/day
    - Setting to $30 provides buffer
  EOT
  type        = number
  default     = 30
}

variable "lambda_daily_limit" {
  description = <<-EOT
    Daily Lambda budget limit in USD.

    CALCULATION:
    - Lambda pricing is complex (GB-seconds + requests)
    - 100 concurrent @ 1GB @ continuous = ~$144/day (extreme)
    - Realistic usage is much lower; $50 catches anomalies
  EOT
  type        = number
  default     = 50
}

variable "dynamodb_daily_limit" {
  description = <<-EOT
    Daily DynamoDB budget limit in USD.

    NOTE: This is critical because DynamoDB capacity cannot be
    limited via SCPs or Service Quotas effectively.

    CALCULATION:
    - On-demand: $1.25 per million writes, $0.25 per million reads
    - Provisioned: $0.00065/WCU-hour, $0.00013/RCU-hour
    - $50/day catches runaway capacity provisioning
  EOT
  type        = number
  default     = 50
}

variable "bedrock_daily_limit" {
  description = <<-EOT
    Daily Bedrock budget limit in USD.

    CALCULATION:
    - Model invocation costs vary widely by model
    - Claude 3 Sonnet: ~$0.003/1K input + $0.015/1K output tokens
    - Heavy experimentation: $50-100/day
    - Setting to $50 allows reasonable usage while catching abuse
  EOT
  type        = number
  default     = 50
}

variable "data_transfer_daily_limit" {
  description = <<-EOT
    Daily data transfer budget limit in USD.

    CALCULATION:
    - Data transfer out: ~$0.09/GB (first 10TB)
    - 100GB out = $9/day
    - $20/day allows significant transfer while catching abuse
  EOT
  type        = number
  default     = 20
}

# -----------------------------------------------------------------------------
# ANOMALY DETECTION (Future Enhancement)
# -----------------------------------------------------------------------------
# AWS Cost Anomaly Detection could be added here for ML-based
# unusual spend detection. Not included in initial implementation
# as it requires Cost Explorer to be enabled and has its own costs.
