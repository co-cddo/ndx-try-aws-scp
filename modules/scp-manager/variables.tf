variable "namespace" {
  description = "The ISB namespace (e.g., 'ndx')"
  type        = string
  default     = "ndx"
}

variable "managed_regions" {
  description = "List of AWS regions allowed for sandbox accounts"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "sandbox_ou_id" {
  description = "The Organization Unit ID for the sandbox OU"
  type        = string
}

variable "nuke_supported_services_policy_id" {
  description = "Policy ID of the existing InnovationSandboxAwsNukeSupportedServicesScp (for import)"
  type        = string
  default     = null
}

variable "limit_regions_policy_id" {
  description = "Policy ID of the existing InnovationSandboxLimitRegionsScp (for import)"
  type        = string
  default     = null
}

variable "enable_cost_avoidance" {
  description = "Whether to create the cost avoidance SCP"
  type        = bool
  default     = true
}

variable "cost_avoidance_ou_id" {
  description = "The OU ID to attach the cost avoidance SCP to (defaults to sandbox_ou_id if not set)"
  type        = string
  default     = null
}

variable "allowed_ec2_instance_types" {
  description = "List of allowed EC2 instance type patterns (e.g., 't3.*', 'm5.large')"
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

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}
