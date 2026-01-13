output "nuke_supported_services_policy_id" {
  description = "ID of the Nuke Supported Services SCP"
  value       = aws_organizations_policy.nuke_supported_services.id
}

output "nuke_supported_services_policy_arn" {
  description = "ARN of the Nuke Supported Services SCP"
  value       = aws_organizations_policy.nuke_supported_services.arn
}

output "limit_regions_policy_id" {
  description = "ID of the Limit Regions SCP"
  value       = aws_organizations_policy.limit_regions.id
}

output "limit_regions_policy_arn" {
  description = "ARN of the Limit Regions SCP"
  value       = aws_organizations_policy.limit_regions.arn
}

output "cost_avoidance_policy_id" {
  description = "ID of the Cost Avoidance SCP (if enabled)"
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance[0].id : null
}

output "cost_avoidance_policy_arn" {
  description = "ARN of the Cost Avoidance SCP (if enabled)"
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance[0].arn : null
}

output "exempt_role_arns" {
  description = "Role ARN patterns that are exempt from SCPs"
  value       = local.exempt_role_arns
}

output "iam_workload_identity_policy_id" {
  description = "ID of the IAM Workload Identity SCP (if enabled)"
  value       = var.enable_iam_workload_identity ? aws_organizations_policy.iam_workload_identity[0].id : null
}

output "iam_workload_identity_policy_arn" {
  description = "ARN of the IAM Workload Identity SCP (if enabled)"
  value       = var.enable_iam_workload_identity ? aws_organizations_policy.iam_workload_identity[0].arn : null
}

output "restrictions_policy_id" {
  description = "ID of the Restrictions SCP (imported from Innovation Sandbox)"
  value       = aws_organizations_policy.restrictions.id
}

output "restrictions_policy_arn" {
  description = "ARN of the Restrictions SCP (imported from Innovation Sandbox)"
  value       = aws_organizations_policy.restrictions.arn
}
