# =============================================================================
# AWS BUDGETS MANAGER - VARIABLES
# =============================================================================
# Budget limits designed for 24-HOUR SANDBOX LEASES.
#
# DEFENSE IN DEPTH:
#   Layer 1: SCPs - What actions are allowed
#   Layer 2: Budgets - How much money can be spent
#   Layer 3: Cost Anomaly Detection - ML-based unusual spending detection
#   Layer 4: DynamoDB Billing Enforcer - Auto-remediation for On-Demand tables
#
# BUDGET CALCULATION:
# Based on SCP-constrained worst-case spending scenarios:
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
  default     = "us-west-2"
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

variable "alert_emails" {
  description = "Email addresses for direct budget alert subscriptions. Required - no default to avoid hardcoding."
  type        = list(string)
  default     = [] # Must be provided by caller
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
  default     = true
}

# -----------------------------------------------------------------------------
# DAILY BUDGET
# -----------------------------------------------------------------------------

variable "daily_budget_name" {
  description = "Name of the daily cost budget (for importing existing budgets). Uses namespace if not specified."
  type        = string
  default     = null # Will be computed from namespace if not set
}

variable "daily_budget_limit" {
  description = <<-EOT
    Daily cost budget limit in USD.

    24-HOUR CALCULATION:
    Based on SCP-constrained resources, maximum theoretical daily spend is ~$250-300.
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

variable "monthly_budget_name" {
  description = "Name of the monthly cost budget (for importing existing budgets). Uses namespace if not specified."
  type        = string
  default     = null # Will be computed from namespace if not set
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

    HOURLY ABUSE CALCULATION:
    - 64 vCPUs @ $0.05/vCPU-hr = $3.20/hour max
    - $10/day budget with 50% threshold = alert at $5
    - Alerts within ~1.5 hours of max compute usage
  EOT
  type        = number
  default     = 10 # AGGRESSIVE: Alerts at $5 (~1.5 hr of max abuse)
}

variable "rds_daily_limit" {
  description = <<-EOT
    Daily RDS budget limit in USD.

    HOURLY ABUSE CALCULATION:
    - 5 x db.m5.large @ $0.171/hr = $0.86/hour max
    - $5/day budget alerts quickly on RDS creation
  EOT
  type        = number
  default     = 5 # AGGRESSIVE: RDS is slow to start, early alert is fine
}

variable "lambda_daily_limit" {
  description = <<-EOT
    Daily Lambda budget limit in USD.

    HOURLY ABUSE CALCULATION:
    - 25 concurrent @ 10GB @ continuous = $15/hour max
    - $10/day budget with 50% threshold = alert at $5
    - Alerts within ~20 minutes of max abuse
  EOT
  type        = number
  default     = 10 # AGGRESSIVE: Alerts at $5 (~20 min of max abuse)
}

variable "dynamodb_daily_limit" {
  description = <<-EOT
    Daily DynamoDB budget limit in USD.

    NOTE: On-Demand mode now auto-converted by billing enforcer.
    This budget catches any residual costs.

    HOURLY CALCULATION:
    - With enforcer: Max 100 WCU × $0.00065/hr = $0.065/hour per table
    - 50 tables × $0.065 = $3.25/hour max
    - $5/day budget alerts quickly
  EOT
  type        = number
  default     = 5 # AGGRESSIVE: Enforcer handles On-Demand, budget is backup
}

variable "bedrock_daily_limit" {
  description = <<-EOT
    Daily Bedrock budget limit in USD.

    HOURLY ABUSE CALCULATION:
    - With 10K tokens/min quota: 600K tokens/hour
    - At $0.015/1K output: ~$9/hour max
    - $10/day budget alerts within first hour
  EOT
  type        = number
  default     = 10 # AGGRESSIVE: AWS default throttle limits throughput, budget catches cost
}

variable "data_transfer_daily_limit" {
  description = <<-EOT
    Daily data transfer budget limit in USD.

    HOURLY CALCULATION:
    - Limited by EC2 instance types (SCP) and NAT count
    - Realistic max: ~50GB/hour = $4.50/hour
    - $10/day budget alerts in ~1 hour of abuse
  EOT
  type        = number
  default     = 10 # AGGRESSIVE: Alerts within first hour of abuse
}

# =============================================================================
# GAP FIX: ADDITIONAL SERVICE BUDGETS
# =============================================================================
# These budgets address cost attack vectors identified in security analysis.

variable "cloudwatch_daily_limit" {
  description = <<-EOT
    Daily CloudWatch budget limit in USD.

    GAP FIX - CRITICAL ATTACK VECTOR:
    CloudWatch Logs ingestion @ $0.50/GB has NO service quota protection.

    HOURLY ABUSE CALCULATION:
    - Lambda flooding logs: 25 concurrent × 5MB/sec × 3600 sec = 450GB/hour
    - 450GB × $0.50/GB = $225/HOUR potential abuse!

    BUDGET STRATEGY (detect <$50 abuse in first hour):
    - $5/day budget with 50% threshold = alert at $2.50
    - At $225/hour abuse rate, alerts in ~40 seconds
  EOT
  type        = number
  default     = 5 # AGGRESSIVE: Alert at $2.50 (50%), detects abuse in <1 min
}

variable "stepfunctions_daily_limit" {
  description = <<-EOT
    Daily Step Functions budget limit in USD.

    HOURLY ABUSE CALCULATION:
    - Max state transitions with 25 Lambda: ~100K/hour = $2.50/hour
    - $5/day budget alerts quickly on abuse patterns
  EOT
  type        = number
  default     = 5 # AGGRESSIVE: Low threshold for early detection
}

variable "s3_daily_limit" {
  description = <<-EOT
    Daily S3 budget limit in USD.

    HOURLY ABUSE CALCULATION:
    - 25 Lambda generating requests: ~1M PUT/hour = $5/hour
    - $10/day budget alerts within first hour of abuse
  EOT
  type        = number
  default     = 10 # AGGRESSIVE: Detects abuse within first hour
}

variable "apigateway_daily_limit" {
  description = <<-EOT
    Daily API Gateway budget limit in USD.

    HOURLY ABUSE CALCULATION:
    - With throttle quota (100 req/sec): 360K requests/hour
    - 360K × $3.50/1M = $1.26/hour
    - $5/day budget alerts quickly
  EOT
  type        = number
  default     = 5 # AGGRESSIVE: Low since AWS default throttle already limits
}

variable "alert_email" {
  description = "Single email address for budget alerts (deprecated, use alert_emails)"
  type        = string
  default     = null
}
