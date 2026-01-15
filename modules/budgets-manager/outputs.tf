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
      for key, config in local.service_budgets :
      key => "$${config.limit}/day"
    } : null

    automated_actions = var.enable_automated_actions ? "Enabled (EC2 stop at 100%)" : "Disabled"
  }
}

output "service_budget_names" {
  description = "Names of service-specific budgets"
  value = var.create_service_budgets ? {
    for key, budget in aws_budgets_budget.service :
    key => budget.name
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

    # For service budgets:
    # terraform import 'module.budgets.aws_budgets_budget.service["ec2"]' <account-id>:<budget-name>

    # To find existing budget names:
    # aws budgets describe-budgets --account-id <account-id> --query 'Budgets[].BudgetName'
  EOT
}
