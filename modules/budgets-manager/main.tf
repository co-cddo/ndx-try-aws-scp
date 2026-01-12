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
# AWS BUDGETS MANAGER
# =============================================================================
# Budgets are the FINAL layer of cost defense:
#   1. SCPs control WHAT actions are allowed
#   2. Service Quotas control HOW MANY resources can exist
#   3. Budgets control HOW MUCH MONEY can be spent
#
# For 24-hour sandbox leases, budgets provide:
#   - Real-time spend tracking
#   - Multi-threshold alerts (50%, 80%, 100%, 120%)
#   - AUTOMATED ACTIONS when limits are breached
#
# Automated actions can:
#   - Stop EC2 instances
#   - Apply restrictive IAM policy
#   - Send SNS notifications
# =============================================================================

# -----------------------------------------------------------------------------
# SNS TOPIC FOR BUDGET ALERTS
# -----------------------------------------------------------------------------
# Central notification topic for all budget alerts.
# Can integrate with email, Slack, PagerDuty, etc.

resource "aws_sns_topic" "budget_alerts" {
  count = var.create_sns_topic ? 1 : 0

  name         = "${var.namespace}-sandbox-budget-alerts"
  display_name = "Innovation Sandbox Budget Alerts"

  tags = merge(var.tags, {
    Purpose = "Budget-Alerts"
  })
}

resource "aws_sns_topic_policy" "budget_alerts" {
  count = var.create_sns_topic ? 1 : 0

  arn = aws_sns_topic.budget_alerts[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alerts[0].arn
      }
    ]
  })
}

# Email subscription if provided
resource "aws_sns_topic_subscription" "budget_email" {
  count = var.create_sns_topic && var.alert_email != null ? 1 : 0

  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR BUDGET ACTIONS
# -----------------------------------------------------------------------------
# This role allows AWS Budgets to execute automated actions like
# stopping EC2 instances when budget thresholds are exceeded.

resource "aws_iam_role" "budget_actions" {
  count = var.enable_automated_actions ? 1 : 0

  name = "${var.namespace}-sandbox-budget-actions"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "Budget-Automated-Actions"
  })
}

resource "aws_iam_role_policy" "budget_actions" {
  count = var.enable_automated_actions ? 1 : 0

  name = "${var.namespace}-sandbox-budget-actions-policy"
  role = aws_iam_role.budget_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Stop"
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/ManagedBy" = "InnovationSandbox"
          }
        }
      },
      {
        Sid    = "AllowRDSStop"
        Effect = "Allow"
        Action = [
          "rds:StopDBInstance",
          "rds:StopDBCluster",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowIAMPolicyAttachment"
        Effect = "Allow"
        Action = [
          "iam:AttachUserPolicy",
          "iam:AttachRolePolicy"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "iam:PolicyArn" = "arn:aws:iam::aws:policy/AWSDenyAll"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# DAILY COST BUDGET (PRIMARY)
# -----------------------------------------------------------------------------
# This is the main budget for 24-hour sandbox leases.
# Tracks actual daily spend against the configured limit.

resource "aws_budgets_budget" "daily_cost" {
  name         = var.daily_budget_name
  budget_type  = "COST"
  limit_amount = tostring(var.daily_budget_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  # Track actual spend (not forecasted)
  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  # Filter to sandbox accounts via linked account or tag
  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  # 10% threshold - early warning (matches existing)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 10
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  # 50% threshold - warning (matches existing)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  # 100% threshold - budget reached (matches existing)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# Automated action: Stop EC2 instances at 100% budget
resource "aws_budgets_budget_action" "stop_ec2_at_100" {
  count = var.enable_automated_actions ? 1 : 0

  budget_name       = aws_budgets_budget.daily_cost.name
  action_type       = "RUN_SSM_DOCUMENTS"
  approval_model    = "AUTOMATIC"
  notification_type = "ACTUAL"
  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100
  }
  execution_role_arn = aws_iam_role.budget_actions[0].arn

  definition {
    ssm_action_definition {
      action_sub_type = "STOP_EC2_INSTANCES"
      region          = var.primary_region
      instance_ids    = [] # Empty = all instances in linked accounts
    }
  }

  subscriber {
    subscription_type = "SNS"
    address           = var.create_sns_topic ? aws_sns_topic.budget_alerts[0].arn : var.sns_topic_arns[0]
  }
}

# -----------------------------------------------------------------------------
# MONTHLY COST BUDGET (AGGREGATE)
# -----------------------------------------------------------------------------
# Provides monthly view across all sandbox accounts.

resource "aws_budgets_budget" "monthly_cost" {
  count = var.create_monthly_budget ? 1 : 0

  name         = var.monthly_budget_name
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  # 85% threshold - warning (matches existing)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  # 100% threshold - budget reached (matches existing)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  # 100% forecasted threshold (matches existing)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# SERVICE-SPECIFIC BUDGETS
# -----------------------------------------------------------------------------
# These catch runaway spending on specific high-cost services.

# EC2 Budget
resource "aws_budgets_budget" "ec2_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-ec2-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.ec2_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Compute Cloud - Compute"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# RDS Budget
resource "aws_budgets_budget" "rds_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-rds-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.rds_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["Amazon Relational Database Service"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# Lambda Budget (catches runaway invocations)
resource "aws_budgets_budget" "lambda_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-lambda-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.lambda_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["AWS Lambda"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# DynamoDB Budget (catches capacity/on-demand overuse)
resource "aws_budgets_budget" "dynamodb_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-dynamodb-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.dynamodb_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["Amazon DynamoDB"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# Bedrock Budget (catches AI/ML usage)
resource "aws_budgets_budget" "bedrock_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-bedrock-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.bedrock_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# Data Transfer Budget (often overlooked cost)
resource "aws_budgets_budget" "data_transfer_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-data-transfer-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.data_transfer_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "UsageType"
    values = ["DataTransfer-Out-Bytes", "DataTransfer-Regional-Bytes"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# =============================================================================
# GAP FIX: ADDITIONAL SERVICE BUDGETS FOR ATTACK VECTORS
# =============================================================================
# These budgets address cost attack vectors identified in security analysis.

# -----------------------------------------------------------------------------
# CloudWatch Logs Budget (CRITICAL - $0.50/GB ingestion)
# -----------------------------------------------------------------------------
# ATTACK SCENARIO: Lambda flooding CloudWatch with log data
# 100 Lambda × 5MB/sec × 24hr = 43.2 TB/day × $0.50/GB = $21,600/day!
# With reduced concurrent (25): Still ~$5,400/day potential
# Budget provides detection and alerting

resource "aws_budgets_budget" "cloudwatch_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-cloudwatch-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.cloudwatch_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["AmazonCloudWatch"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  # Early warning at 50% for this critical gap
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Step Functions Budget (HIGH - $0.025/1000 state transitions)
# -----------------------------------------------------------------------------
# ATTACK SCENARIO: State machines with many states triggered in loops
# Could generate millions of state transitions = $100s-$1000s/day

resource "aws_budgets_budget" "stepfunctions_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-stepfunctions-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.stepfunctions_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["AWS Step Functions"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# S3 Budget (MEDIUM - $5/million PUT requests)
# -----------------------------------------------------------------------------
# ATTACK SCENARIO: Scripts generating millions of S3 PUT/LIST requests
# With compute limits: ~$400-500/day potential

resource "aws_budgets_budget" "s3_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-s3-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.s3_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["Amazon Simple Storage Service"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# API Gateway Budget (MEDIUM - $3.50/million requests)
# -----------------------------------------------------------------------------
# ATTACK SCENARIO: Scripts generating millions of API requests
# Combined with throttling quota, limits exposure

resource "aws_budgets_budget" "apigateway_daily" {
  count = var.create_service_budgets ? 1 : 0

  name         = "${var.namespace}-sandbox-apigateway-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.apigateway_daily_limit)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  cost_filter {
    name   = "Service"
    values = ["Amazon API Gateway"]
  }

  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns
  }

  tags = var.tags
}
