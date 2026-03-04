# =============================================================================
# OU METRICS CLOUDWATCH ALARMS - VARIABLES
# =============================================================================
# Alarms for Innovation Sandbox OU account pool metrics published to
# the InnovationSandbox/OUMetrics namespace.
#
# See: https://github.com/co-cddo/innovation-sandbox-on-aws-ou-metrics

# -----------------------------------------------------------------------------
# GENERAL CONFIGURATION
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "The ISB namespace (e.g., 'ndx')"
  type        = string
  default     = "ndx"
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# ALARM THRESHOLDS
# -----------------------------------------------------------------------------

variable "available_accounts_threshold" {
  description = <<-EOT
    Alarm when AvailableAccounts drops below this value.
    Pool running low — users may not be able to get a sandbox.
  EOT
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# EVALUATION CONFIGURATION
# -----------------------------------------------------------------------------

variable "metric_period_seconds" {
  description = "Period in seconds for metric evaluation (should match the publishing interval)"
  type        = number
  default     = 900 # 15 minutes
}
