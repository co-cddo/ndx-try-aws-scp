# =============================================================================
# COST ANOMALY DETECTION - OUTPUTS
# =============================================================================

output "monitor_arn" {
  description = "ARN of the main cost anomaly monitor (null if using existing monitors)"
  value       = var.create_monitors ? aws_ce_anomaly_monitor.main[0].arn : null
}

output "monitor_id" {
  description = "ID of the main cost anomaly monitor (null if using existing monitors)"
  value       = var.create_monitors ? aws_ce_anomaly_monitor.main[0].id : null
}

output "linked_account_monitor_arn" {
  description = "ARN of the linked account cost anomaly monitor (if enabled and created)"
  value       = var.create_monitors && var.monitor_linked_accounts ? aws_ce_anomaly_monitor.linked_accounts[0].arn : null
}

output "effective_monitor_arns" {
  description = "List of monitor ARNs being used (created or existing)"
  value       = local.effective_monitor_arns
}

output "subscription_arn" {
  description = "ARN of the cost anomaly subscription"
  value       = local.create_subscriptions ? aws_ce_anomaly_subscription.main[0].arn : null
}

output "high_priority_subscription_arn" {
  description = "ARN of the high-priority cost anomaly subscription (if enabled)"
  value       = local.create_subscriptions && var.enable_high_priority_alerts ? aws_ce_anomaly_subscription.high_priority[0].arn : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for anomaly alerts"
  value       = var.create_sns_topic ? aws_sns_topic.cost_anomaly_alerts[0].arn : var.existing_sns_topic_arn
}

output "anomaly_detection_summary" {
  description = "Summary of cost anomaly detection configuration"
  value = {
    service                 = "AWS Cost Anomaly Detection"
    cost                    = "FREE"
    monitors_created        = var.create_monitors
    monitors_used           = length(local.effective_monitor_arns)
    monitor_source          = var.create_monitors ? "CREATED" : "EXISTING"
    alert_frequency         = var.alert_frequency
    threshold_amount        = "$${var.alert_threshold_amount}"
    high_priority_enabled   = var.enable_high_priority_alerts
    high_priority_threshold = var.enable_high_priority_alerts ? "$${var.high_priority_threshold_amount}" : "N/A"
    learning_period         = "~2 weeks to learn spending patterns"
    evaluation_frequency    = "~24 hours"
  }
}
