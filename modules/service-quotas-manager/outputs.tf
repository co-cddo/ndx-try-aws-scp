# =============================================================================
# SERVICE QUOTAS MANAGER - OUTPUTS
# =============================================================================

output "regions" {
  description = "List of regions where service quotas are applied"
  value       = var.regions
}

output "ec2_on_demand_vcpu_limit" {
  description = "EC2 On-Demand Standard vCPU limit"
  value       = var.enable_ec2_quotas ? var.ec2_on_demand_vcpu_limit : null
}

output "ec2_gpu_vcpu_limit" {
  description = "EC2 GPU vCPU limit"
  value       = var.enable_ec2_quotas ? var.ec2_gpu_vcpu_limit : null
}

output "ebs_total_storage_tib" {
  description = "Total EBS storage limit (gp2 + gp3) in TiB"
  value       = var.enable_ebs_quotas ? var.ebs_gp2_storage_tib + var.ebs_gp3_storage_tib : null
}

output "lambda_concurrent_executions" {
  description = "Lambda concurrent execution limit"
  value       = var.enable_lambda_quotas ? var.lambda_concurrent_executions : null
}

output "rds_instance_limit" {
  description = "RDS instance limit"
  value       = var.enable_rds_quotas ? var.rds_instance_limit : null
}

output "rds_storage_limit_gb" {
  description = "RDS total storage limit in GB"
  value       = var.enable_rds_quotas ? var.rds_total_storage_gb : null
}

output "template_association_enabled" {
  description = "Whether Service Quota Template association is enabled"
  value       = var.enable_template_association
}

output "estimated_max_daily_cost" {
  description = "Estimated maximum daily cost based on quota limits (rough approximation)"
  value = format("$%.2f/day (estimated)", sum([
    # EC2: 64 vCPUs @ $0.05/vCPU-hr * 24 = $76.80
    var.enable_ec2_quotas ? var.ec2_on_demand_vcpu_limit * 0.05 * 24 : 0,
    # EBS: 2 TiB @ $3/TiB-day = $6
    var.enable_ebs_quotas ? (var.ebs_gp2_storage_tib + var.ebs_gp3_storage_tib) * 3 : 0,
    # RDS: 5 instances @ $4/day = $20
    var.enable_rds_quotas ? var.rds_instance_limit * 4 : 0,
    # ElastiCache: 10 nodes @ $4/day = $40
    var.enable_elasticache_quotas ? var.elasticache_node_limit * 4 : 0,
    # EKS: 2 clusters @ $2.40/day = $4.80
    var.enable_eks_quotas ? var.eks_cluster_limit * 2.4 : 0,
    # ALB/NLB: 10 total @ $0.54/day = $5.40
    var.enable_elb_quotas ? (var.alb_limit + var.nlb_limit) * 0.54 : 0,
    # NAT Gateways: 6 (2/AZ * 3 AZ) @ $1.08/day = $6.48
    var.enable_vpc_quotas ? var.nat_gateway_per_az_limit * 3 * 1.08 : 0,
  ]))
}

output "quota_summary" {
  description = "Summary of all quota limits for documentation"
  value = {
    ec2 = var.enable_ec2_quotas ? {
      on_demand_vcpus = var.ec2_on_demand_vcpu_limit
      spot_vcpus      = var.ec2_spot_vcpu_limit
      gpu_vcpus       = var.ec2_gpu_vcpu_limit
      p_vcpus         = var.ec2_p_instance_vcpu_limit
      inf_vcpus       = var.ec2_inf_vcpu_limit
    } : null

    ebs = var.enable_ebs_quotas ? {
      gp3_storage_tib = var.ebs_gp3_storage_tib
      gp2_storage_tib = var.ebs_gp2_storage_tib
      io1_iops        = var.ebs_io1_iops_limit
      io2_iops        = var.ebs_io2_iops_limit
      snapshot_count  = var.ebs_snapshot_limit
    } : null

    lambda = var.enable_lambda_quotas ? {
      concurrent_executions = var.lambda_concurrent_executions
    } : null

    vpc = var.enable_vpc_quotas ? {
      vpc_count           = var.vpc_limit
      nat_gateways_per_az = var.nat_gateway_per_az_limit
      elastic_ips         = var.elastic_ip_limit
    } : null

    rds = var.enable_rds_quotas ? {
      instance_count           = var.rds_instance_limit
      total_storage_gb         = var.rds_total_storage_gb
      read_replicas_per_source = var.rds_read_replicas_per_source
    } : null

    elasticache = var.enable_elasticache_quotas ? {
      node_count = var.elasticache_node_limit
    } : null

    eks = var.enable_eks_quotas ? {
      cluster_count = var.eks_cluster_limit
    } : null

    elb = var.enable_elb_quotas ? {
      alb_count = var.alb_limit
      nlb_count = var.nlb_limit
    } : null

    dynamodb = var.enable_dynamodb_quotas ? {
      table_count = var.dynamodb_table_limit
    } : null

    kinesis = var.enable_kinesis_quotas ? {
      shard_count = var.kinesis_shard_limit
    } : null

    cloudwatch = var.enable_cloudwatch_quotas ? {
      log_group_count = var.cloudwatch_log_group_limit
    } : null
  }
}
