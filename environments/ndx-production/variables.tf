variable "aws_region" {
  description = "AWS region for provider (Organizations API is global but needs a region)"
  type        = string
  default     = "us-east-1"
}

variable "namespace" {
  description = "The ISB namespace"
  type        = string
  default     = "ndx"
}

variable "managed_regions" {
  description = "AWS regions allowed for sandbox accounts"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "sandbox_ou_id" {
  description = "Organization Unit ID for the sandbox OU (e.g., ou-xxxx-xxxxxxxx)"
  type        = string
}

variable "enable_cost_avoidance" {
  description = "Whether to create cost avoidance SCP"
  type        = bool
  default     = true
}

variable "cost_avoidance_ou_id" {
  description = "OU ID to attach cost avoidance SCP (defaults to Active OU for running sandboxes)"
  type        = string
  default     = null
}

variable "allowed_ec2_instance_types" {
  description = "EC2 instance types allowed in sandboxes"
  type        = list(string)
  default = [
    "t2.micro",
    "t2.small",
    "t2.medium",
    "t3.micro",
    "t3.small",
    "t3.medium",
    "t3.large",
    "t3a.micro",
    "t3a.small",
    "t3a.medium",
    "t3a.large",
    "m5.large",
    "m5.xlarge",
    "m6i.large",
    "m6i.xlarge"
  ]
}

# =============================================================================
# AWS BUDGETS (PER-ACCOUNT FROM POOL OU)
# =============================================================================
# Budgets are automatically created for each account discovered in the sandbox
# pool OU. This scales automatically as new pool accounts are added.

variable "enable_budgets" {
  description = "Enable AWS Budgets for cost tracking and alerts"
  type        = bool
  default     = true
}

variable "sandbox_pool_ou_id" {
  description = <<-EOT
    Organization Unit ID containing sandbox pool accounts.

    All ACTIVE accounts in this OU will automatically get budgets created.
    As new accounts are added to the pool, re-running terraform creates their budgets.

    Example: ou-xxxx-xxxxxxxx (e.g., the "Active" or "Pool" OU)
  EOT
  type        = string
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alert notifications"
  type        = list(string)
  default = [
    "chris.Nesbitt-Smith@digital.cabinet-office.gov.uk",
    "ndx-aaaaqa6ovbj5owumuw4jkzc44m@gds.slack.com",
    "ndx@dsit.gov.uk"
  ]
}

variable "daily_budget_limit" {
  description = "Daily cost budget limit in USD PER ACCOUNT"
  type        = number
  default     = 50
}

variable "monthly_budget_limit" {
  description = "Monthly cost budget limit in USD PER ACCOUNT"
  type        = number
  default     = 1000
}

variable "enable_service_budgets" {
  description = "Enable service-specific budgets (EC2, RDS, Lambda, etc.)"
  type        = bool
  default     = true
}

variable "ec2_daily_budget" {
  description = "Daily EC2 compute budget in USD (consolidated across all accounts)"
  type        = number
  default     = 100
}

variable "rds_daily_budget" {
  description = "Daily RDS budget in USD (consolidated across all accounts)"
  type        = number
  default     = 30
}

variable "lambda_daily_budget" {
  description = "Daily Lambda budget in USD (consolidated across all accounts)"
  type        = number
  default     = 50
}

variable "dynamodb_daily_budget" {
  description = "Daily DynamoDB budget in USD (consolidated across all accounts)"
  type        = number
  default     = 50
}

variable "bedrock_daily_budget" {
  description = "Daily Bedrock AI budget in USD (consolidated across all accounts)"
  type        = number
  default     = 50
}

variable "data_transfer_daily_budget" {
  description = "Daily data transfer budget in USD (consolidated across all accounts)"
  type        = number
  default     = 20
}

variable "enable_budget_automated_actions" {
  description = "Enable automated budget actions (stop EC2 at 100%). CAUTION: Will stop running instances."
  type        = bool
  default     = false
}
