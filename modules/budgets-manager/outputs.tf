# =============================================================================
# AWS BUDGETS MANAGER - OUTPUTS
# =============================================================================

output "sns_topic_arn" {
  description = "ARN of the SNS topic for budget alerts"
  value       = var.create_sns_topic ? aws_sns_topic.budget_alerts[0].arn : null
}

output "daily_budget_name" {
  description = "Name of the daily cost budget (consolidated mode only)"
  value       = var.sandbox_account_ids == null ? aws_budgets_budget.daily_cost[0].name : null
}

output "daily_budget_names_per_account" {
  description = "Map of account IDs to daily budget names (per-account mode)"
  value = var.sandbox_account_ids != null ? {
    for account_id, budget in aws_budgets_budget.daily_cost_per_account :
    account_id => budget.name
  } : null
}

output "monthly_budget_name" {
  description = "Name of the monthly cost budget (consolidated mode only)"
  value       = var.create_monthly_budget && var.sandbox_account_ids == null ? aws_budgets_budget.monthly_cost[0].name : null
}

output "monthly_budget_names_per_account" {
  description = "Map of account IDs to monthly budget names (per-account mode)"
  value = var.create_monthly_budget && var.sandbox_account_ids != null ? {
    for account_id, budget in aws_budgets_budget.monthly_cost_per_account :
    account_id => budget.name
  } : null
}

output "budget_action_role_arn" {
  description = "ARN of the IAM role for automated budget actions"
  value       = var.enable_automated_actions && var.sandbox_account_ids == null ? aws_iam_role.budget_actions[0].arn : null
}

output "budget_limits_summary" {
  description = "Summary of configured budget limits"
  value = {
    mode          = var.sandbox_account_ids != null ? "per-account" : "consolidated"
    account_count = var.sandbox_account_ids != null ? length(var.sandbox_account_ids) : 0
    daily_limit   = "$${var.daily_budget_limit}/day per account"
    monthly_limit = var.create_monthly_budget ? "$${var.monthly_budget_limit}/month per account" : "Not configured"

    service_budgets = var.create_service_budgets ? {
      ec2           = "$${var.ec2_daily_limit}/day"
      rds           = "$${var.rds_daily_limit}/day"
      lambda        = "$${var.lambda_daily_limit}/day"
      dynamodb      = "$${var.dynamodb_daily_limit}/day"
      bedrock       = "$${var.bedrock_daily_limit}/day"
      data_transfer = "$${var.data_transfer_daily_limit}/day"
      cloudwatch    = "$${var.cloudwatch_daily_limit}/day"
      stepfunctions = "$${var.stepfunctions_daily_limit}/day"
      s3            = "$${var.s3_daily_limit}/day"
      apigateway    = "$${var.apigateway_daily_limit}/day"
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
    cloudwatch    = aws_budgets_budget.cloudwatch_daily[0].name
    stepfunctions = aws_budgets_budget.stepfunctions_daily[0].name
    s3            = aws_budgets_budget.s3_daily[0].name
    apigateway    = aws_budgets_budget.apigateway_daily[0].name
  } : null
}

output "import_commands" {
  description = "Commands to import existing budgets (if they exist in AWS)"
  value       = <<-EOT
    # If budgets already exist from ClickOps, import them:
    # terraform import 'module.budgets.aws_budgets_budget.daily_cost[0]' <account-id>:<budget-name>
    # terraform import 'module.budgets.aws_budgets_budget.monthly_cost[0]' <account-id>:<budget-name>

    # For per-account budgets:
    # terraform import 'module.budgets.aws_budgets_budget.daily_cost_per_account["<sandbox-account-id>"]' <management-account-id>:<budget-name>

    # To find existing budget names:
    # aws budgets describe-budgets --account-id <account-id> --query 'Budgets[].BudgetName'
  EOT
}
