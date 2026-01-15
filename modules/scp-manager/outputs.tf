output "nuke_supported_services_policy_id" {
  description = "ID of the Nuke Supported Services SCP"
  value       = aws_organizations_policy.nuke_supported_services.id
}

output "nuke_supported_services_policy_arn" {
  description = "ARN of the Nuke Supported Services SCP"
  value       = aws_organizations_policy.nuke_supported_services.arn
}

# DEPRECATED: limit_regions has been consolidated into restrictions SCP
# These outputs now point to the restrictions policy for backwards compatibility
output "limit_regions_policy_id" {
  description = "DEPRECATED: Region restrictions consolidated into Restrictions SCP. Returns restrictions policy ID."
  value       = aws_organizations_policy.restrictions.id
}

output "limit_regions_policy_arn" {
  description = "DEPRECATED: Region restrictions consolidated into Restrictions SCP. Returns restrictions policy ARN."
  value       = aws_organizations_policy.restrictions.arn
}

output "cost_avoidance_policy_id" {
  description = "ID of the Cost Avoidance SCP"
  value       = aws_organizations_policy.cost_avoidance.id
}

output "cost_avoidance_policy_arn" {
  description = "ARN of the Cost Avoidance SCP"
  value       = aws_organizations_policy.cost_avoidance.arn
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
