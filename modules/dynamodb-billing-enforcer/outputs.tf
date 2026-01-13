# =============================================================================
# DYNAMODB BILLING MODE ENFORCER - OUTPUTS
# =============================================================================

output "lambda_function_arn" {
  description = "ARN of the DynamoDB billing enforcer Lambda function"
  value       = aws_lambda_function.enforcer.arn
}

output "lambda_function_name" {
  description = "Name of the DynamoDB billing enforcer Lambda function"
  value       = aws_lambda_function.enforcer.function_name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule that triggers enforcement"
  value       = aws_cloudwatch_event_rule.dynamodb_table_changes.arn
}

output "enforcement_summary" {
  description = "Summary of DynamoDB billing enforcement configuration"
  value = {
    action          = "DELETE"
    exempt_prefixes = var.exempt_table_prefixes
    notifications   = var.sns_topic_arn != null ? "Enabled" : "Disabled"
    eventbridge     = "Broadcasts 'DynamoDB On-Demand Table Deleted' events"
    cost_protection = "On-Demand tables are DELETED to prevent unlimited costs"
  }
}
