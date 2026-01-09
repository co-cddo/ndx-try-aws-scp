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
