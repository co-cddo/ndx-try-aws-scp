# Cost Anomaly Detection - ML-based spending pattern alerts (FREE service)
# AWS limit: 10 DIMENSIONAL monitors per account. Use create_monitors=false to reuse existing.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

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

resource "aws_sns_topic_subscription" "email" {
  count = var.create_sns_topic ? length(var.alert_emails) : 0

  topic_arn = aws_sns_topic.cost_anomaly_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

data "aws_caller_identity" "current" {}

resource "aws_ce_anomaly_monitor" "main" {
  count = var.create_monitors ? 1 : 0

  name              = "${var.namespace}-cost-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = merge(var.tags, {
    Name = "${var.namespace}-cost-anomaly-monitor"
  })
}

resource "aws_ce_anomaly_monitor" "linked_accounts" {
  count = var.create_monitors && var.monitor_linked_accounts ? 1 : 0

  name              = "${var.namespace}-linked-account-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "LINKED_ACCOUNT"

  tags = merge(var.tags, {
    Name = "${var.namespace}-linked-account-anomaly-monitor"
  })
}

locals {
  effective_monitor_arns = var.create_monitors ? compact([
    aws_ce_anomaly_monitor.main[0].arn,
    var.monitor_linked_accounts ? aws_ce_anomaly_monitor.linked_accounts[0].arn : ""
  ]) : var.existing_monitor_arns

  create_subscriptions = length(local.effective_monitor_arns) > 0
}

resource "aws_ce_anomaly_subscription" "main" {
  count = local.create_subscriptions ? 1 : 0

  name      = "${var.namespace}-cost-anomaly-subscription"
  frequency = var.alert_frequency

  monitor_arn_list = local.effective_monitor_arns

  subscriber {
    type    = "SNS"
    address = var.create_sns_topic ? aws_sns_topic.cost_anomaly_alerts[0].arn : var.existing_sns_topic_arn
  }

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
