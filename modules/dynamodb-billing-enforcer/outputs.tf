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
    enforcement_mode   = var.enforcement_mode
    max_rcu_on_convert = var.max_rcu
    max_wcu_on_convert = var.max_wcu
    exempt_prefixes    = var.exempt_table_prefixes
    notifications      = var.sns_topic_arn != null ? "Enabled" : "Disabled"
    cost_protection    = <<-EOT
      PROTECTION PROVIDED:
      - Detects any DynamoDB table created/updated with On-Demand billing
      - Automatically converts to Provisioned mode with ${var.max_rcu} RCU, ${var.max_wcu} WCU
      - Maximum cost after conversion: ~$${format("%.2f", var.max_wcu * 0.00065 * 24 + var.max_rcu * 0.00013 * 24)}/day
      - Without this protection: UNLIMITED On-Demand costs possible
    EOT
  }
}
