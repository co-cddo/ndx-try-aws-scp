# =============================================================================
# COST ANOMALY DETECTION - VARIABLES
# =============================================================================
# AWS Cost Anomaly Detection is FREE. These variables configure the
# sensitivity and notification preferences.
# =============================================================================

# -----------------------------------------------------------------------------
# GENERAL CONFIGURATION
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Namespace prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# SNS CONFIGURATION
# -----------------------------------------------------------------------------

variable "create_sns_topic" {
  description = "Create a new SNS topic for anomaly alerts. Set to false to use existing topic."
  type        = bool
  default     = true
}

variable "existing_sns_topic_arn" {
  description = "ARN of existing SNS topic to use (required if create_sns_topic is false)"
  type        = string
  default     = null
}

variable "alert_emails" {
  description = "Email addresses for anomaly alert notifications"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# MONITOR CONFIGURATION
# -----------------------------------------------------------------------------

variable "create_monitors" {
  description = <<-EOT
    Whether to create new anomaly monitors.

    AWS LIMIT: Maximum 10 DIMENSIONAL monitors per account.

    Set to FALSE if:
    - The account already has 10 monitors (AWS limit reached)
    - You want to use existing monitors instead

    When false, you must provide existing_monitor_arns.

    To list existing monitors:
      aws ce get-anomaly-monitors --query 'AnomalyMonitors[*].{Name:MonitorName,ARN:MonitorArn,Type:MonitorType}'
  EOT
  type        = bool
  default     = true
}

variable "existing_monitor_arns" {
  description = <<-EOT
    List of existing anomaly monitor ARNs to use instead of creating new ones.
    Required when create_monitors = false.

    Example:
      existing_monitor_arns = [
        "arn:aws:ce::123456789012:anomalymonitor/abc123-def456-789"
      ]
  EOT
  type        = list(string)
  default     = []
}

variable "monitor_linked_accounts" {
  description = "Create additional monitor for linked account spending patterns (only when create_monitors = true)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ALERT CONFIGURATION
# -----------------------------------------------------------------------------

variable "alert_frequency" {
  description = <<-EOT
    How often to receive anomaly alerts:
    - IMMEDIATE: As soon as anomaly is detected (within ~24 hours of spend)
    - DAILY: Daily digest of anomalies
    - WEEKLY: Weekly digest of anomalies

    Recommendation: DAILY for general monitoring, IMMEDIATE for production
  EOT
  type        = string
  default     = "DAILY"

  validation {
    condition     = contains(["IMMEDIATE", "DAILY", "WEEKLY"], var.alert_frequency)
    error_message = "Alert frequency must be IMMEDIATE, DAILY, or WEEKLY."
  }
}

variable "alert_threshold_amount" {
  description = <<-EOT
    Minimum anomaly impact (USD) to trigger an alert.
    Set to 0 to receive all anomaly alerts.

    For 24-hour sandboxes with $50/day budget:
    - $5: Catch small anomalies (may be noisy initially)
    - $10: Balanced threshold (recommended)
    - $25: Only major anomalies (50% of daily budget)
  EOT
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# HIGH-PRIORITY ALERTS
# -----------------------------------------------------------------------------

variable "enable_high_priority_alerts" {
  description = <<-EOT
    Enable separate IMMEDIATE alerts for large anomalies.
    Use this to get instant notification of significant cost spikes
    while keeping regular alerts on a daily/weekly schedule.
  EOT
  type        = bool
  default     = true
}

variable "high_priority_threshold_amount" {
  description = <<-EOT
    Minimum anomaly impact (USD) to trigger HIGH-PRIORITY immediate alert.
    Should be higher than alert_threshold_amount.

    For 24-hour sandboxes with $50/day budget:
    - $25: Half of daily budget
    - $50: Full daily budget exceeded (recommended)
    - $100: Double daily budget
  EOT
  type        = number
  default     = 50
}
