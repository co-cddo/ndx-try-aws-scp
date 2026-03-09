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

# =============================================================================
# OU METRICS ALARMS
# =============================================================================
# CloudWatch alarms for account pool health metrics.
# See: https://github.com/co-cddo/innovation-sandbox-on-aws-ou-metrics

variable "enable_ou_metrics_alarms" {
  description = "Enable CloudWatch alarms for OU account pool metrics"
  type        = bool
  default     = true
}

variable "ou_metrics_sns_topic_arn" {
  description = "SNS topic ARN for OU metrics and DynamoDB billing enforcer alerts"
  type        = string
  default     = null
}

variable "available_accounts_threshold" {
  description = "Alarm when available accounts drops below this value"
  type        = number
  default     = 30
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
