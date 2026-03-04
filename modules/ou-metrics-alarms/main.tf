terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# =============================================================================
# OU METRICS CLOUDWATCH ALARMS
# =============================================================================
# Monitors account pool health metrics published to the
# InnovationSandbox/OUMetrics namespace by the OU metrics Lambda.
#
# See: https://github.com/co-cddo/innovation-sandbox-on-aws-ou-metrics

locals {
  metric_namespace = "InnovationSandbox/OUMetrics"
  alarm_prefix     = "${var.namespace}-ou-metrics"
}

# -----------------------------------------------------------------------------
# LOW AVAILABLE ACCOUNTS
# -----------------------------------------------------------------------------
# Pool running low — users may not be able to get a sandbox.

resource "aws_cloudwatch_metric_alarm" "low_available_accounts" {
  alarm_name          = "${local.alarm_prefix}-low-available-accounts"
  alarm_description   = "Available sandbox accounts dropped below ${var.available_accounts_threshold}. Pool running low — users may not be able to get a sandbox."
  comparison_operator = "LessThanThreshold"
  threshold           = var.available_accounts_threshold
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "AvailableAccounts"
  namespace           = local.metric_namespace
  period              = var.metric_period_seconds
  statistic           = "Minimum"
  treat_missing_data  = "missing"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# NON-ZERO ENTRY ACCOUNTS (STUCK IN TRANSITION)
# -----------------------------------------------------------------------------
# Accounts stuck entering the pool for over an hour.

resource "aws_cloudwatch_metric_alarm" "stuck_entry_accounts" {
  alarm_name          = "${local.alarm_prefix}-stuck-entry-accounts"
  alarm_description   = "Entry accounts have been non-zero for 4 consecutive datapoints (~1 hour). Accounts may be stuck transitioning into the pool."
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 4
  datapoints_to_alarm = 4
  metric_name         = "EntryAccounts"
  namespace           = local.metric_namespace
  period              = var.metric_period_seconds
  statistic           = "Maximum"
  treat_missing_data  = "missing"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# NON-ZERO EXIT ACCOUNTS (STUCK IN TRANSITION)
# -----------------------------------------------------------------------------
# Accounts stuck leaving the pool for over an hour.

resource "aws_cloudwatch_metric_alarm" "stuck_exit_accounts" {
  alarm_name          = "${local.alarm_prefix}-stuck-exit-accounts"
  alarm_description   = "Exit accounts have been non-zero for 4 consecutive datapoints (~1 hour). Accounts may be stuck transitioning out of the pool."
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 4
  datapoints_to_alarm = 4
  metric_name         = "ExitAccounts"
  namespace           = local.metric_namespace
  period              = var.metric_period_seconds
  statistic           = "Maximum"
  treat_missing_data  = "missing"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# METRICS GOING STALE
# -----------------------------------------------------------------------------
# If TotalManagedAccounts stops being published, the Lambda may have failed.
# Uses treat_missing_data = "breaching" so INSUFFICIENT_DATA triggers the alarm.

resource "aws_cloudwatch_metric_alarm" "metrics_stale" {
  alarm_name          = "${local.alarm_prefix}-metrics-stale"
  alarm_description   = "OU metrics have not been published for ~30 minutes. The metrics Lambda may have failed or been disabled."
  comparison_operator = "LessThanThreshold"
  threshold           = 0
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "TotalManagedAccounts"
  namespace           = local.metric_namespace
  period              = var.metric_period_seconds
  statistic           = "SampleCount"
  treat_missing_data  = "breaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = var.tags
}
