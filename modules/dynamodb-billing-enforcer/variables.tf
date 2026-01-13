# =============================================================================
# DYNAMODB BILLING MODE ENFORCER - VARIABLES
# =============================================================================

variable "namespace" {
  description = "The ISB namespace (e.g., 'ndx')"
  type        = string
  default     = "ndx"
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for enforcement alerts. If null, no SNS notifications sent."
  type        = string
  default     = null
}

variable "exempt_table_prefixes" {
  description = <<-EOT
    List of table name prefixes to exempt from enforcement.
    Tables starting with these prefixes will not be deleted.

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
