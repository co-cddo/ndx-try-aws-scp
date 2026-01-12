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
