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

variable "cost_avoidance_ou_id" {
  description = "The OU ID to attach the cost avoidance SCP to (defaults to sandbox_ou_id if not set)"
  type        = string
  default     = null
}

variable "allowed_ec2_instance_types" {
  description = "List of allowed EC2 instance type patterns (e.g., 't3.*', 'm5.large'). Pass null to use default."
  type        = list(string)
  default     = null # See locals.default_ec2_instance_types
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

variable "denied_ec2_instance_types" {
  description = "EC2 instance types to deny (GPU, accelerated, very large). Uses wildcards for SCP size."
  type        = list(string)
  default     = ["p*", "g*", "inf*", "trn*", "dl*", "u-*", "*.metal*", "*.12xlarge", "*.16xlarge", "*.18xlarge", "*.24xlarge", "*.32xlarge", "*.48xlarge"]
}

variable "allowed_rds_instance_classes" {
  description = "RDS instance classes allowed. Uses wildcards for SCP size."
  type        = list(string)
  default     = ["db.t3.*", "db.t4g.*", "db.m5.large", "db.m5.xlarge", "db.m6g.large", "db.m6g.xlarge", "db.m6i.large", "db.m6i.xlarge"]
}

variable "allow_rds_multi_az" {
  description = "Whether to allow RDS Multi-AZ deployments (doubles cost)"
  type        = bool
  default     = false
}

variable "allowed_elasticache_node_types" {
  description = "ElastiCache node types allowed. Uses wildcards for SCP size."
  type        = list(string)
  default     = ["cache.t3.*", "cache.t4g.*", "cache.m5.large", "cache.m6g.large"]
}

variable "max_ebs_volume_size_gb" {
  description = "Maximum EBS volume size in GB"
  type        = number
  default     = 500
}

variable "denied_ebs_volume_types" {
  description = "EBS volume types to deny (io1/io2 are expensive provisioned IOPS)"
  type        = list(string)
  default     = ["io1", "io2"]
}

variable "block_lambda_provisioned_concurrency" {
  description = "Block Lambda provisioned concurrency (expensive always-on)"
  type        = bool
  default     = true
}

variable "block_expensive_services" {
  description = "Expensive service actions to block. Uses wildcards for SCP size."
  type        = list(string)
  default = [
    "kafka:Create*", "fsx:CreateFileSystem", "kinesis:CreateStream", "quicksight:*User",
    "ec2:AllocateDedicatedHosts", "ec2:PurchaseReserved*", "rds:PurchaseReserved*",
    "elasticache:PurchaseReserved*", "savingsplans:CreateSavingsPlan",
    "neptune:Create*", "docdb:Create*", "memorydb:CreateCluster",
    "es:Create*", "opensearch:Create*",
    "batch:CreateComputeEnvironment", "glue:CreateJob", "glue:CreateDevEndpoint",
    "timestream:Create*", "qldb:CreateLedger"
  ]
}

variable "max_autoscaling_group_size" {
  description = "Maximum Auto Scaling group MaxSize parameter"
  type        = number
  default     = 10
}

variable "block_rds_read_replicas" {
  description = "Block creation of RDS read replicas (each replica = additional cost)"
  type        = bool
  default     = true
}

variable "block_rds_provisioned_iops" {
  description = "Block RDS provisioned IOPS (very expensive)"
  type        = bool
  default     = true
}

variable "max_eks_nodegroup_size" {
  description = "Maximum EKS nodegroup size (maxSize parameter)"
  type        = number
  default     = 5
}

variable "enable_cost_avoidance" {
  description = "Whether to create cost avoidance SCP"
  type        = bool
  default     = true
}

variable "denied_bedrock_model_patterns" {
  description = "Bedrock model ARN patterns to deny (cost avoidance)"
  type        = list(string)
  default = [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude*opus*",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude*sonnet*",
  ]
}

variable "enable_iam_workload_identity" {
  description = "Enable IAM Workload Identity SCP for workload roles while preventing privilege escalation"
  type        = bool
  default     = false
}
