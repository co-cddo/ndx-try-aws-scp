# =============================================================================
# AWS BUDGETS MANAGER - OUTPUTS
# =============================================================================

output "sns_topic_arn" {
  description = "ARN of the SNS topic for budget alerts"
  value       = var.create_sns_topic ? aws_sns_topic.budget_alerts[0].arn : null
}

output "daily_budget_name" {
  description = "Name of the daily cost budget"
  value       = aws_budgets_budget.daily_cost.name
}

output "monthly_budget_name" {
  description = "Name of the monthly cost budget"
  value       = var.create_monthly_budget ? aws_budgets_budget.monthly_cost[0].name : null
}

output "budget_action_role_arn" {
  description = "ARN of the IAM role for automated budget actions"
  value       = var.enable_automated_actions ? aws_iam_role.budget_actions[0].arn : null
}

output "budget_limits_summary" {
  description = "Summary of configured budget limits"
  value = {
    daily_total   = "$${var.daily_budget_limit}/day"
    monthly_total = var.create_monthly_budget ? "$${var.monthly_budget_limit}/month" : "Not configured"

    service_budgets = var.create_service_budgets ? {
      ec2           = "$${var.ec2_daily_limit}/day"
      rds           = "$${var.rds_daily_limit}/day"
      lambda        = "$${var.lambda_daily_limit}/day"
      dynamodb      = "$${var.dynamodb_daily_limit}/day"
      bedrock       = "$${var.bedrock_daily_limit}/day"
      data_transfer = "$${var.data_transfer_daily_limit}/day"
    } : null

    automated_actions = var.enable_automated_actions ? "Enabled (EC2 stop at 100%)" : "Disabled"
  }
}

output "service_budget_names" {
  description = "Names of service-specific budgets"
  value = var.create_service_budgets ? {
    ec2           = aws_budgets_budget.ec2_daily[0].name
    rds           = aws_budgets_budget.rds_daily[0].name
    lambda        = aws_budgets_budget.lambda_daily[0].name
    dynamodb      = aws_budgets_budget.dynamodb_daily[0].name
    bedrock       = aws_budgets_budget.bedrock_daily[0].name
    data_transfer = aws_budgets_budget.data_transfer_daily[0].name
  } : null
}

output "import_commands" {
  description = "Commands to import existing budgets (if they exist in AWS)"
  value       = <<-EOT
    # If budgets already exist from ClickOps, import them:
    # terraform import 'module.budgets.aws_budgets_budget.daily_cost' <account-id>:<budget-name>
    # terraform import 'module.budgets.aws_budgets_budget.monthly_cost[0]' <account-id>:<budget-name>

    # To find existing budget names:
    # aws budgets describe-budgets --account-id <account-id> --query 'Budgets[].BudgetName'
  EOT
}
