# =============================================================================
# DYNAMODB BILLING MODE ENFORCER - VARIABLES
# =============================================================================

variable "namespace" {
  description = "The ISB namespace (e.g., 'ndx')"
  type        = string
  default     = "ndx"
}

variable "enforcement_mode" {
  description = <<-EOT
    Enforcement action when On-Demand table is detected:
    - "convert": Convert table to PROVISIONED mode with enforced capacity limits (RECOMMENDED)
    - "delete": Delete the table entirely (AGGRESSIVE - use with caution)
    - "alert": Send alert only, take no remediation action (PASSIVE)

    RECOMMENDATION: Use "convert" for production. This ensures the table still
    works but with predictable, bounded costs.
  EOT
  type        = string
  default     = "convert"

  validation {
    condition     = contains(["convert", "delete", "alert"], var.enforcement_mode)
    error_message = "enforcement_mode must be one of: convert, delete, alert"
  }
}

variable "max_rcu" {
  description = <<-EOT
    Maximum Read Capacity Units when converting On-Demand table to Provisioned.

    COST ANALYSIS:
    - 100 RCU × $0.00013/RCU-hour × 24hr = $0.31/day
    - This is the capacity the table will be set to after conversion.
    - Should match or be lower than your service quota RCU limit.
  EOT
  type        = number
  default     = 100
}

variable "max_wcu" {
  description = <<-EOT
    Maximum Write Capacity Units when converting On-Demand table to Provisioned.

    COST ANALYSIS:
    - 100 WCU × $0.00065/WCU-hour × 24hr = $1.56/day
    - This is the capacity the table will be set to after conversion.
    - Should match or be lower than your service quota WCU limit.
  EOT
  type        = number
  default     = 100
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for enforcement alerts. If null, no SNS notifications sent."
  type        = string
  default     = null
}

variable "exempt_table_prefixes" {
  description = <<-EOT
    List of table name prefixes to exempt from enforcement.
    Tables starting with these prefixes will not be converted/deleted.

    Example: ["terraform-state-", "infrastructure-"]
  EOT
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}
