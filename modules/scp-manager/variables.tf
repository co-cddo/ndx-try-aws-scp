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

# =============================================================================
# ENHANCED COST AVOIDANCE VARIABLES
# =============================================================================

variable "denied_ec2_instance_types" {
  description = "EC2 instance type patterns to explicitly deny (GPU, accelerated computing, very large)"
  type        = list(string)
  default = [
    # GPU instances - extremely expensive ($3-32+/hour)
    "p2.*", "p3.*", "p4d.*", "p4de.*", "p5.*",
    # Graphics instances
    "g3.*", "g3s.*", "g4dn.*", "g4ad.*", "g5.*", "g5g.*", "g6.*",
    # Inference/ML accelerators
    "inf1.*", "inf2.*",
    # Training instances
    "trn1.*", "trn1n.*", "trn2.*",
    # Deep learning
    "dl1.*", "dl2q.*",
    # High memory (6TB-24TB RAM)
    "u-6tb1.*", "u-9tb1.*", "u-12tb1.*", "u-18tb1.*", "u-24tb1.*",
    # Very large metal instances
    "*.metal", "*.metal-24xl", "*.metal-48xl",
    # X-large instance families (12xlarge and above)
    "*.12xlarge", "*.16xlarge", "*.18xlarge", "*.24xlarge", "*.32xlarge", "*.48xlarge"
  ]
}

variable "allowed_rds_instance_classes" {
  description = "RDS DB instance classes allowed (uses db.* prefix)"
  type        = list(string)
  default = [
    # Burstable (good for dev/test)
    "db.t3.micro", "db.t3.small", "db.t3.medium", "db.t3.large",
    "db.t4g.micro", "db.t4g.small", "db.t4g.medium", "db.t4g.large",
    # General purpose (reasonable production)
    "db.m5.large", "db.m5.xlarge",
    "db.m6g.large", "db.m6g.xlarge",
    "db.m6i.large", "db.m6i.xlarge"
  ]
}

variable "allow_rds_multi_az" {
  description = "Whether to allow RDS Multi-AZ deployments (doubles cost)"
  type        = bool
  default     = false
}

variable "max_rds_storage_gb" {
  description = "Maximum RDS storage size in GB"
  type        = number
  default     = 100
}

variable "allowed_elasticache_node_types" {
  description = "ElastiCache node types allowed"
  type        = list(string)
  default = [
    "cache.t3.micro", "cache.t3.small", "cache.t3.medium",
    "cache.t4g.micro", "cache.t4g.small", "cache.t4g.medium",
    "cache.m5.large", "cache.m6g.large"
  ]
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
  description = "List of expensive service actions to completely block"
  type        = list(string)
  default = [
    # MSK (Kafka) - very expensive ($0.21-2.88/hour per broker)
    "kafka:CreateCluster",
    "kafka:CreateClusterV2",
    # FSx - expensive managed file systems
    "fsx:CreateFileSystem",
    # Kinesis Data Streams - per-shard pricing adds up
    "kinesis:CreateStream",
    # QuickSight - per-user pricing
    "quicksight:CreateUser",
    "quicksight:RegisterUser",
    # Dedicated hosts
    "ec2:AllocateDedicatedHosts",
    # Reserved capacity (commitment)
    "ec2:PurchaseReservedInstancesOffering",
    "rds:PurchaseReservedDBInstancesOffering",
    "elasticache:PurchaseReservedCacheNodesOffering",
    # Savings plans (commitment)
    "savingsplans:CreateSavingsPlan"
  ]
}

variable "max_eks_nodegroup_size" {
  description = "Maximum EKS nodegroup size (maxSize parameter)"
  type        = number
  default     = 5
}

variable "max_ecs_task_count" {
  description = "Maximum ECS service desired count"
  type        = number
  default     = 10
}
