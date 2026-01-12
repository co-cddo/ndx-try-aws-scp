# =============================================================================
# DYNAMODB BILLING MODE ENFORCER
# =============================================================================
# GAP FIX: DynamoDB On-Demand mode bypasses WCU/RCU service quotas.
#
# PROBLEM:
# - Service Quotas only limit PROVISIONED capacity (WCU/RCU)
# - On-Demand mode has NO capacity quotas - it's purely pay-per-request
# - Attacker can create On-Demand tables and generate unlimited costs
# - There is NO SCP condition key for dynamodb:BillingMode
#
# SOLUTION:
# EventBridge rule detects CreateTable/UpdateTable events and triggers
# Lambda function that either:
#   1. Converts table to PROVISIONED mode with enforced capacity limits
#   2. Deletes the table (aggressive mode)
#   3. Alerts and logs (passive mode)
#
# This provides the missing layer of defense for DynamoDB On-Demand costs.
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# LAMBDA FUNCTION FOR DYNAMODB ENFORCEMENT
# -----------------------------------------------------------------------------

data "archive_file" "enforcer_lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import os

dynamodb = boto3.client('dynamodb')
sns = boto3.client('sns')

ENFORCEMENT_MODE = os.environ.get('ENFORCEMENT_MODE', 'convert')  # convert, delete, alert
MAX_RCU = int(os.environ.get('MAX_RCU', '100'))
MAX_WCU = int(os.environ.get('MAX_WCU', '100'))
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
EXEMPT_TABLE_PREFIXES = os.environ.get('EXEMPT_TABLE_PREFIXES', '').split(',')

def lambda_handler(event, context):
    """
    Enforces DynamoDB billing mode policy.
    Triggered by EventBridge when CreateTable or UpdateTable is called.
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        detail = event.get('detail', {})
        event_name = detail.get('eventName', '')

        # Extract table name from the API call
        request_params = detail.get('requestParameters', {})
        table_name = request_params.get('tableName', '')

        if not table_name:
            print("No table name found in event")
            return {'statusCode': 200, 'body': 'No table name'}

        # Check if table is exempt
        for prefix in EXEMPT_TABLE_PREFIXES:
            if prefix and table_name.startswith(prefix.strip()):
                print(f"Table {table_name} is exempt (prefix: {prefix})")
                return {'statusCode': 200, 'body': f'Table {table_name} exempt'}

        # Get current table status
        try:
            response = dynamodb.describe_table(TableName=table_name)
            table = response['Table']
            billing_mode = table.get('BillingModeSummary', {}).get('BillingMode', 'PROVISIONED')
        except dynamodb.exceptions.ResourceNotFoundException:
            print(f"Table {table_name} not found (may have been deleted)")
            return {'statusCode': 200, 'body': 'Table not found'}

        print(f"Table {table_name} has billing mode: {billing_mode}")

        # If table is On-Demand, take action
        if billing_mode == 'PAY_PER_REQUEST':
            message = f"DynamoDB table '{table_name}' detected with On-Demand billing mode."

            if ENFORCEMENT_MODE == 'convert':
                # Convert to provisioned with enforced limits
                try:
                    dynamodb.update_table(
                        TableName=table_name,
                        BillingMode='PROVISIONED',
                        ProvisionedThroughput={
                            'ReadCapacityUnits': MAX_RCU,
                            'WriteCapacityUnits': MAX_WCU
                        }
                    )
                    message += f" CONVERTED to PROVISIONED mode with {MAX_RCU} RCU, {MAX_WCU} WCU."
                    print(message)
                except Exception as e:
                    message += f" FAILED to convert: {str(e)}"
                    print(message)

            elif ENFORCEMENT_MODE == 'delete':
                # Delete the table (aggressive)
                try:
                    dynamodb.delete_table(TableName=table_name)
                    message += " TABLE DELETED (aggressive enforcement mode)."
                    print(message)
                except Exception as e:
                    message += f" FAILED to delete: {str(e)}"
                    print(message)

            else:  # alert mode
                message += " ALERT ONLY - no action taken."
                print(message)

            # Send SNS notification
            if SNS_TOPIC_ARN:
                try:
                    sns.publish(
                        TopicArn=SNS_TOPIC_ARN,
                        Subject=f"[COST ALERT] DynamoDB On-Demand Table Detected: {table_name}",
                        Message=message
                    )
                except Exception as e:
                    print(f"Failed to send SNS notification: {str(e)}")

            return {'statusCode': 200, 'body': message}

        return {'statusCode': 200, 'body': f'Table {table_name} is already provisioned'}

    except Exception as e:
        print(f"Error processing event: {str(e)}")
        raise

PYTHON
    filename = "index.py"
  }
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
          "dynamodb:UpdateTable",
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
      ENFORCEMENT_MODE      = var.enforcement_mode
      MAX_RCU               = tostring(var.max_rcu)
      MAX_WCU               = tostring(var.max_wcu)
      SNS_TOPIC_ARN         = var.sns_topic_arn != null ? var.sns_topic_arn : ""
      EXEMPT_TABLE_PREFIXES = join(",", var.exempt_table_prefixes)
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EVENTBRIDGE RULE TO DETECT DYNAMODB TABLE OPERATIONS
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP (with controlled retention)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "enforcer_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.enforcer.function_name}"
  retention_in_days = 7 # Short retention for cost control

  tags = var.tags
}
