# =============================================================================
# COST ANOMALY DETECTION MODULE
# =============================================================================
# AWS Cost Anomaly Detection uses ML to identify unusual spending patterns.
# This is a FREE service - you only pay for the resources being monitored.
#
# Features:
# - ML-based anomaly detection (learns spending patterns over ~2 weeks)
# - Near real-time alerts (evaluates every ~24 hours)
# - Configurable thresholds to reduce noise
# - SNS/email notifications
#
# Integration with Defense in Depth:
#   Layer 1: SCPs - What actions are allowed
#   Layer 2: Service Quotas - How many resources can exist
#   Layer 3: Budgets - Hard spend limits with automated actions
#   Layer 4: Anomaly Detection - ML-based unusual pattern detection
#
# AWS LIMITS:
# - Maximum 10 DIMENSIONAL monitors per account
# - If you hit this limit, set create_monitors = false and pass existing
#   monitor ARNs via existing_monitor_arns variable
#
# USAGE MODES:
# 1. Full mode (default): Creates monitors + subscriptions
#    create_monitors = true (default)
#
# 2. Subscription-only mode: Uses existing monitors, creates subscriptions only
#    create_monitors = false
#    existing_monitor_arns = ["arn:aws:ce::123456789012:anomalymonitor/abc123"]
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# SNS TOPIC FOR ANOMALY ALERTS
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "cost_anomaly_alerts" {
  count = var.create_sns_topic ? 1 : 0

  name         = "${var.namespace}-cost-anomaly-alerts"
  display_name = "${upper(var.namespace)} Cost Anomaly Alerts"

  tags = merge(var.tags, {
    Name = "${var.namespace}-cost-anomaly-alerts"
  })
}

resource "aws_sns_topic_policy" "cost_anomaly_alerts" {
  count = var.create_sns_topic ? 1 : 0

  arn = aws_sns_topic.cost_anomaly_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCostExplorerPublish"
        Effect = "Allow"
        Principal = {
          Service = "costalerts.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.cost_anomaly_alerts[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscriptions for anomaly alerts
resource "aws_sns_topic_subscription" "email" {
  count = var.create_sns_topic ? length(var.alert_emails) : 0

  topic_arn = aws_sns_topic.cost_anomaly_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# COST ANOMALY MONITOR
# -----------------------------------------------------------------------------
# The monitor defines WHAT to monitor for anomalies.
# We create a service-level monitor to catch anomalies across all AWS services.
#
# NOTE: AWS allows maximum 10 DIMENSIONAL monitors per account.
# If you hit this limit, set create_monitors = false and use existing_monitor_arns.

resource "aws_ce_anomaly_monitor" "main" {
  count = var.create_monitors ? 1 : 0

  name              = "${var.namespace}-cost-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = merge(var.tags, {
    Name = "${var.namespace}-cost-anomaly-monitor"
  })
}

# Optional: Linked account monitor for multi-account setups
resource "aws_ce_anomaly_monitor" "linked_accounts" {
  count = var.create_monitors && var.monitor_linked_accounts ? 1 : 0

  name              = "${var.namespace}-linked-account-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "LINKED_ACCOUNT"

  tags = merge(var.tags, {
    Name = "${var.namespace}-linked-account-anomaly-monitor"
  })
}

# Compute effective monitor ARNs - either from created monitors or existing ones
locals {
  # Use created monitor ARNs if we're creating them, otherwise use existing
  effective_monitor_arns = var.create_monitors ? compact([
    aws_ce_anomaly_monitor.main[0].arn,
    var.monitor_linked_accounts ? aws_ce_anomaly_monitor.linked_accounts[0].arn : ""
  ]) : var.existing_monitor_arns

  # Only create subscriptions if we have monitor ARNs to attach to
  create_subscriptions = length(local.effective_monitor_arns) > 0
}

# -----------------------------------------------------------------------------
# COST ANOMALY SUBSCRIPTION
# -----------------------------------------------------------------------------
# The subscription defines HOW to be notified when anomalies are detected.
# Subscriptions use either created monitors or existing monitor ARNs.

resource "aws_ce_anomaly_subscription" "main" {
  count = local.create_subscriptions ? 1 : 0

  name      = "${var.namespace}-cost-anomaly-subscription"
  frequency = var.alert_frequency

  monitor_arn_list = local.effective_monitor_arns

  subscriber {
    type    = "SNS"
    address = var.create_sns_topic ? aws_sns_topic.cost_anomaly_alerts[0].arn : var.existing_sns_topic_arn
  }

  # Threshold expression to filter out noise
  # Only alert when impact is above the configured threshold
  dynamic "threshold_expression" {
    for_each = var.alert_threshold_amount > 0 ? [1] : []
    content {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = [tostring(var.alert_threshold_amount)]
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.namespace}-cost-anomaly-subscription"
  })
}

# -----------------------------------------------------------------------------
# OPTIONAL: HIGH-PRIORITY SUBSCRIPTION FOR LARGE ANOMALIES
# -----------------------------------------------------------------------------
# Separate subscription for immediate alerts on large anomalies

resource "aws_ce_anomaly_subscription" "high_priority" {
  count = local.create_subscriptions && var.enable_high_priority_alerts ? 1 : 0

  name      = "${var.namespace}-high-priority-anomaly-subscription"
  frequency = "IMMEDIATE"

  monitor_arn_list = local.effective_monitor_arns

  subscriber {
    type    = "SNS"
    address = var.create_sns_topic ? aws_sns_topic.cost_anomaly_alerts[0].arn : var.existing_sns_topic_arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.high_priority_threshold_amount)]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.namespace}-high-priority-anomaly-subscription"
  })
}
