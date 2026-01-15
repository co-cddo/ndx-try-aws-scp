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

# Cost Avoidance SCPs - Split into two for AWS 5,120 character limit
output "cost_avoidance_compute_policy_id" {
  description = "ID of the Cost Avoidance Compute SCP (EC2, EBS, RDS, ElastiCache, EKS, ASG, Lambda)"
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance_compute[0].id : null
}

output "cost_avoidance_compute_policy_arn" {
  description = "ARN of the Cost Avoidance Compute SCP"
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance_compute[0].arn : null
}

output "cost_avoidance_services_policy_id" {
  description = "ID of the Cost Avoidance Services SCP (blocks expensive services)"
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance_services[0].id : null
}

output "cost_avoidance_services_policy_arn" {
  description = "ARN of the Cost Avoidance Services SCP"
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance_services[0].arn : null
}

# DEPRECATED: Kept for backwards compatibility - returns compute policy
output "cost_avoidance_policy_id" {
  description = "DEPRECATED: Cost Avoidance split into compute/services. Returns compute policy ID."
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance_compute[0].id : null
}

output "cost_avoidance_policy_arn" {
  description = "DEPRECATED: Cost Avoidance split into compute/services. Returns compute policy ARN."
  value       = var.enable_cost_avoidance ? aws_organizations_policy.cost_avoidance_compute[0].arn : null
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
