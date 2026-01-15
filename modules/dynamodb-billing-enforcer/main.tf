# DynamoDB Billing Mode Enforcer - deletes On-Demand tables (bypass WCU/RCU quotas)

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

data "archive_file" "enforcer_lambda" {
  type        = "zip"
  output_path = "${path.module}/.lambda.zip"
  source_dir  = "${path.module}/lambda"
  excludes    = ["__pycache__", "*.pyc", ".DS_Store"]
}

# Lambda execution role
resource "aws_iam_role" "enforcer_lambda" {
  name = "${var.namespace}-dynamodb-billing-enforcer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "enforcer_lambda" {
  name = "${var.namespace}-dynamodb-billing-enforcer-policy"
  role = aws_iam_role.enforcer_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:DeleteTable"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic_arn != null ? var.sns_topic_arn : "*"
      },
      {
        Sid      = "EventBridgePutEvents"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "enforcer" {
  filename         = data.archive_file.enforcer_lambda.output_path
  function_name    = "${var.namespace}-dynamodb-billing-enforcer"
  role             = aws_iam_role.enforcer_lambda.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.enforcer_lambda.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  environment {
    variables = {
      SNS_TOPIC_ARN         = var.sns_topic_arn != null ? var.sns_topic_arn : ""
      EXEMPT_TABLE_PREFIXES = join(",", var.exempt_table_prefixes)
      EVENT_BUS_NAME        = "default"
      EVENTBRIDGE_SOURCE    = "${var.namespace}.dynamodb-billing-enforcer"
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "dynamodb_table_changes" {
  name        = "${var.namespace}-dynamodb-billing-enforcer"
  description = "Detects DynamoDB CreateTable and UpdateTable events for billing mode enforcement"

  event_pattern = jsonencode({
    source      = ["aws.dynamodb"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["dynamodb.amazonaws.com"]
      eventName   = ["CreateTable", "UpdateTable"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "invoke_enforcer_lambda" {
  rule      = aws_cloudwatch_event_rule.dynamodb_table_changes.name
  target_id = "InvokeEnforcerLambda"
  arn       = aws_lambda_function.enforcer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.enforcer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dynamodb_table_changes.arn
}

resource "aws_cloudwatch_log_group" "enforcer_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.enforcer.function_name}"
  retention_in_days = 7 # Short retention for cost control

  tags = var.tags
}
