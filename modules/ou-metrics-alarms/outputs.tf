# =============================================================================
# OU METRICS CLOUDWATCH ALARMS - OUTPUTS
# =============================================================================

output "alarm_arns" {
  description = "Map of alarm names to their ARNs"
  value = {
    low_available_accounts = aws_cloudwatch_metric_alarm.low_available_accounts.arn
    stuck_entry_accounts   = aws_cloudwatch_metric_alarm.stuck_entry_accounts.arn
    stuck_exit_accounts    = aws_cloudwatch_metric_alarm.stuck_exit_accounts.arn
    metrics_stale          = aws_cloudwatch_metric_alarm.metrics_stale.arn
  }
}

output "alarm_summary" {
  description = "Summary of configured OU metrics alarms"
  value = {
    available_threshold = "< ${var.available_accounts_threshold} accounts"
    entry_exit_stuck    = "> 0 for 4 datapoints (~1 hour)"
    stale_detection     = "no data for ~30 minutes"
  }
}
