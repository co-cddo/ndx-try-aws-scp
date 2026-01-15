variable "namespace" {
  description = "Namespace prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

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

variable "create_monitors" {
  description = "Create new monitors. Set false if account has 10 monitors (AWS limit). Use existing_monitor_arns instead."
  type        = bool
  default     = true
}

variable "existing_monitor_arns" {
  description = "Existing monitor ARNs to use when create_monitors=false"
  type        = list(string)
  default     = []
}

variable "monitor_linked_accounts" {
  description = "Create additional monitor for linked account spending patterns (only when create_monitors = true)"
  type        = bool
  default     = true
}

variable "alert_frequency" {
  description = "Alert frequency: IMMEDIATE, DAILY, or WEEKLY"
  type        = string
  default     = "DAILY"

  validation {
    condition     = contains(["IMMEDIATE", "DAILY", "WEEKLY"], var.alert_frequency)
    error_message = "Alert frequency must be IMMEDIATE, DAILY, or WEEKLY."
  }
}

variable "alert_threshold_amount" {
  description = "Minimum anomaly impact (USD) to trigger alert. 0 = all alerts."
  type        = number
  default     = 10
}

variable "enable_high_priority_alerts" {
  description = "Enable separate IMMEDIATE alerts for large anomalies"
  type        = bool
  default     = true
}

variable "high_priority_threshold_amount" {
  description = "Minimum anomaly impact (USD) to trigger immediate high-priority alert"
  type        = number
  default     = 50
}
