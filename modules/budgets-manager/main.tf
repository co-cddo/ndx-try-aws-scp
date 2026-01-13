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
# DRY: CENTRALIZED CONFIGURATION
# =============================================================================
# All repeated values extracted to locals for maintainability.

locals {
  # Budget unit constants
  budget_limit_unit = "USD"
  daily_time_unit   = "DAILY"
  monthly_time_unit = "MONTHLY"

  # SNS topic ARN - used in all notification blocks
  notification_sns_arns = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : var.sns_topic_arns

  # Standard cost_types configuration - identical for ALL budgets
  # Extracted to avoid 140+ lines of duplication
  standard_cost_types = {
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

  # Service budget configurations - enables for_each pattern
  # Each service only needs: name, limit variable, and filter config
  service_budgets = var.create_service_budgets ? {
    ec2 = {
      name         = "${var.namespace}-sandbox-ec2-daily"
      limit        = var.ec2_daily_limit
      filter_name  = "Service"
      filter_value = ["Amazon Elastic Compute Cloud - Compute"]
      thresholds   = [80, 100]
    }
    rds = {
      name         = "${var.namespace}-sandbox-rds-daily"
      limit        = var.rds_daily_limit
      filter_name  = "Service"
      filter_value = ["Amazon Relational Database Service"]
      thresholds   = [80, 100]
    }
    lambda = {
      name         = "${var.namespace}-sandbox-lambda-daily"
      limit        = var.lambda_daily_limit
      filter_name  = "Service"
      filter_value = ["AWS Lambda"]
      thresholds   = [80, 100]
    }
    dynamodb = {
      name         = "${var.namespace}-sandbox-dynamodb-daily"
      limit        = var.dynamodb_daily_limit
      filter_name  = "Service"
      filter_value = ["Amazon DynamoDB"]
      thresholds   = [80, 100]
    }
    bedrock = {
      name         = "${var.namespace}-sandbox-bedrock-daily"
      limit        = var.bedrock_daily_limit
      filter_name  = "Service"
      filter_value = ["Amazon Bedrock"]
      thresholds   = [50, 80, 100] # Extra 50% threshold for AI costs
    }
    data_transfer = {
      name         = "${var.namespace}-sandbox-data-transfer-daily"
      limit        = var.data_transfer_daily_limit
      filter_name  = "UsageType"
      filter_value = ["DataTransfer-Out-Bytes", "DataTransfer-Regional-Bytes"]
      thresholds   = [80, 100]
    }
    cloudwatch = {
      name         = "${var.namespace}-sandbox-cloudwatch-daily"
      limit        = var.cloudwatch_daily_limit
      filter_name  = "Service"
      filter_value = ["AmazonCloudWatch"]
      thresholds   = [50, 80, 100] # Extra 50% threshold - critical gap
    }
    stepfunctions = {
      name         = "${var.namespace}-sandbox-stepfunctions-daily"
      limit        = var.stepfunctions_daily_limit
      filter_name  = "Service"
      filter_value = ["AWS Step Functions"]
      thresholds   = [80, 100]
    }
    s3 = {
      name         = "${var.namespace}-sandbox-s3-daily"
      limit        = var.s3_daily_limit
      filter_name  = "Service"
      filter_value = ["Amazon Simple Storage Service"]
      thresholds   = [80, 100]
    }
    apigateway = {
      name         = "${var.namespace}-sandbox-apigateway-daily"
      limit        = var.apigateway_daily_limit
      filter_name  = "Service"
      filter_value = ["Amazon API Gateway"]
      thresholds   = [80, 100]
    }
  } : {}
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
#   - Multi-threshold alerts (50%, 80%, 100%)
#   - AUTOMATED ACTIONS when limits are breached
# =============================================================================

# -----------------------------------------------------------------------------
# SNS TOPIC FOR BUDGET ALERTS
# -----------------------------------------------------------------------------

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

resource "aws_sns_topic_subscription" "budget_email" {
  count = var.create_sns_topic && var.alert_email != null ? 1 : 0

  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR BUDGET ACTIONS
# -----------------------------------------------------------------------------

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
# DAILY COST BUDGET - PER ACCOUNT
# -----------------------------------------------------------------------------

resource "aws_budgets_budget" "daily_cost_per_account" {
  for_each = var.sandbox_account_ids != null ? toset(var.sandbox_account_ids) : toset([])

  name         = "${var.namespace}-sandbox-daily-${each.value}"
  budget_type  = "COST"
  limit_amount = tostring(var.daily_budget_limit)
  limit_unit   = local.budget_limit_unit
  time_unit    = local.daily_time_unit

  cost_types {
    include_credit             = local.standard_cost_types.include_credit
    include_discount           = local.standard_cost_types.include_discount
    include_other_subscription = local.standard_cost_types.include_other_subscription
    include_recurring          = local.standard_cost_types.include_recurring
    include_refund             = local.standard_cost_types.include_refund
    include_subscription       = local.standard_cost_types.include_subscription
    include_support            = local.standard_cost_types.include_support
    include_tax                = local.standard_cost_types.include_tax
    include_upfront            = local.standard_cost_types.include_upfront
    use_blended                = local.standard_cost_types.use_blended
  }

  cost_filter {
    name   = "LinkedAccount"
    values = [each.value]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 10
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  tags = merge(var.tags, {
    SandboxAccountId = each.value
  })
}

# -----------------------------------------------------------------------------
# DAILY COST BUDGET - CONSOLIDATED (FALLBACK)
# -----------------------------------------------------------------------------

resource "aws_budgets_budget" "daily_cost" {
  count = var.sandbox_account_ids == null ? 1 : 0

  name         = coalesce(var.daily_budget_name, "${upper(var.namespace)} sandbox daily")
  budget_type  = "COST"
  limit_amount = tostring(var.daily_budget_limit)
  limit_unit   = local.budget_limit_unit
  time_unit    = local.daily_time_unit

  cost_types {
    include_credit             = local.standard_cost_types.include_credit
    include_discount           = local.standard_cost_types.include_discount
    include_other_subscription = local.standard_cost_types.include_other_subscription
    include_recurring          = local.standard_cost_types.include_recurring
    include_refund             = local.standard_cost_types.include_refund
    include_subscription       = local.standard_cost_types.include_subscription
    include_support            = local.standard_cost_types.include_support
    include_tax                = local.standard_cost_types.include_tax
    include_upfront            = local.standard_cost_types.include_upfront
    use_blended                = local.standard_cost_types.use_blended
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 10
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  tags = var.tags
}

resource "aws_budgets_budget_action" "stop_ec2_at_100" {
  count = var.enable_automated_actions && var.sandbox_account_ids == null ? 1 : 0

  budget_name       = aws_budgets_budget.daily_cost[0].name
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
      instance_ids    = []
    }
  }

  subscriber {
    subscription_type = "SNS"
    address           = var.create_sns_topic ? aws_sns_topic.budget_alerts[0].arn : var.sns_topic_arns[0]
  }
}

# -----------------------------------------------------------------------------
# MONTHLY COST BUDGET - PER ACCOUNT
# -----------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly_cost_per_account" {
  for_each = var.create_monthly_budget && var.sandbox_account_ids != null ? toset(var.sandbox_account_ids) : toset([])

  name         = "${var.namespace}-sandbox-monthly-${each.value}"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit)
  limit_unit   = local.budget_limit_unit
  time_unit    = local.monthly_time_unit

  cost_types {
    include_credit             = local.standard_cost_types.include_credit
    include_discount           = local.standard_cost_types.include_discount
    include_other_subscription = local.standard_cost_types.include_other_subscription
    include_recurring          = local.standard_cost_types.include_recurring
    include_refund             = local.standard_cost_types.include_refund
    include_subscription       = local.standard_cost_types.include_subscription
    include_support            = local.standard_cost_types.include_support
    include_tax                = local.standard_cost_types.include_tax
    include_upfront            = local.standard_cost_types.include_upfront
    use_blended                = local.standard_cost_types.use_blended
  }

  cost_filter {
    name   = "LinkedAccount"
    values = [each.value]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  tags = merge(var.tags, {
    SandboxAccountId = each.value
  })
}

# -----------------------------------------------------------------------------
# MONTHLY COST BUDGET - CONSOLIDATED (FALLBACK)
# -----------------------------------------------------------------------------

resource "aws_budgets_budget" "monthly_cost" {
  count = var.create_monthly_budget && var.sandbox_account_ids == null ? 1 : 0

  name         = coalesce(var.monthly_budget_name, "${upper(var.namespace)} sandbox monthly")
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit)
  limit_unit   = local.budget_limit_unit
  time_unit    = local.monthly_time_unit

  cost_types {
    include_credit             = local.standard_cost_types.include_credit
    include_discount           = local.standard_cost_types.include_discount
    include_other_subscription = local.standard_cost_types.include_other_subscription
    include_recurring          = local.standard_cost_types.include_recurring
    include_refund             = local.standard_cost_types.include_refund
    include_subscription       = local.standard_cost_types.include_subscription
    include_support            = local.standard_cost_types.include_support
    include_tax                = local.standard_cost_types.include_tax
    include_upfront            = local.standard_cost_types.include_upfront
    use_blended                = local.standard_cost_types.use_blended
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.notification_sns_arns
  }

  tags = var.tags
}

# =============================================================================
# SERVICE-SPECIFIC BUDGETS (DRY: using for_each)
# =============================================================================
# All service budgets use the same structure, differing only in:
# - Budget name and limit
# - Service/UsageType filter
# - Alert thresholds (some services get extra 50% threshold)
#
# This reduces ~600 lines of duplicated code to ~50 lines.

resource "aws_budgets_budget" "service" {
  for_each = local.service_budgets

  name         = each.value.name
  budget_type  = "COST"
  limit_amount = tostring(each.value.limit)
  limit_unit   = local.budget_limit_unit
  time_unit    = local.daily_time_unit

  cost_types {
    include_credit             = local.standard_cost_types.include_credit
    include_discount           = local.standard_cost_types.include_discount
    include_other_subscription = local.standard_cost_types.include_other_subscription
    include_recurring          = local.standard_cost_types.include_recurring
    include_refund             = local.standard_cost_types.include_refund
    include_subscription       = local.standard_cost_types.include_subscription
    include_support            = local.standard_cost_types.include_support
    include_tax                = local.standard_cost_types.include_tax
    include_upfront            = local.standard_cost_types.include_upfront
    use_blended                = local.standard_cost_types.use_blended
  }

  # Service or UsageType filter
  cost_filter {
    name   = each.value.filter_name
    values = each.value.filter_value
  }

  # LinkedAccount filter (only when sandbox_account_ids is set)
  dynamic "cost_filter" {
    for_each = var.sandbox_account_ids != null ? [1] : []
    content {
      name   = "LinkedAccount"
      values = var.sandbox_account_ids
    }
  }

  # Dynamic notifications based on configured thresholds
  dynamic "notification" {
    for_each = toset(each.value.thresholds)
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.alert_emails
      subscriber_sns_topic_arns  = local.notification_sns_arns
    }
  }

  tags = var.tags
}
