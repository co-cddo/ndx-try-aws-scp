terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  # Standard role ARN patterns that are exempt from SCPs
  exempt_role_arns = [
    "arn:aws:iam::*:role/InnovationSandbox-${var.namespace}*",
    "arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*AWSReservedSSO_${var.namespace}_IsbAdmins*",
    "arn:aws:iam::*:role/stacksets-exec-*",
    "arn:aws:iam::*:role/AWSControlTowerExecution"
  ]
}

# =============================================================================
# MODIFIED SCP: AWS Nuke Supported Services
# =============================================================================
# This SCP uses NotAction to ALLOW only services that AWS Nuke can clean up.
# We ADD services here to make them available to sandbox users.

resource "aws_organizations_policy" "nuke_supported_services" {
  name        = "InnovationSandboxAwsNukeSupportedServicesScp"
  description = "SCP to allow only services supported by AWS Nuke clean workflow. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllExceptAwsNukeSupportedServices"
        Effect    = "Deny"
        NotAction = local.nuke_supported_services
        Resource  = ["*"]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach to sandbox OU
resource "aws_organizations_policy_attachment" "nuke_supported_services" {
  policy_id = aws_organizations_policy.nuke_supported_services.id
  target_id = var.sandbox_ou_id
}

locals {
  # Services supported by AWS Nuke + our additions (textract, secrets manager enhancements)
  nuke_supported_services = [
    "access-analyzer:*",
    "acm:*",
    "acm-pca:*",
    "amplify:*",
    "aoss:*",
    "apigateway:*",
    "appconfig:*",
    "application-autoscaling:*",
    "applicationinsights:*",
    "appmesh:*",
    "apprunner:*",
    "appstream:*",
    "appsync:*",
    "athena:*",
    "autoscaling:*",
    "backup:*",
    "batch:*",
    "bedrock:*",
    "budgets:*",
    "cloud9:*",
    "clouddirectory:*",
    "cloudformation:*",
    "cloudfront:*",
    "cloudhsm:*",
    "cloudsearch:*",
    "cloudshell:*",
    "cloudtrail:*",
    "cloudwatch:*",
    "codebuild:*",
    "codecommit:*",
    "codedeploy:*",
    "codeguru-profiler:*",
    "codeguru-reviewer:*",
    "codepipeline:*",
    "codestar:*",
    "cognito-identity:*",
    "cognito-idp:*",
    "comprehend:*",
    "config:*",
    "dms:*",
    "datapipeline:*",
    "dax:*",
    "devicefarm:*",
    "ds:*",
    "dynamodb:*",
    "ec2:*",
    "ec2messages:*",
    "ecr:*",
    "ecs:*",
    "elasticfilesystem:*",
    "eks:*",
    "elasticache:*",
    "elasticbeanstalk:*",
    "es:*",
    "elastictranscoder:*",
    "elasticloadbalancing:*",
    "elasticmapreduce:*",
    "events:*",
    "firehose:*",
    "fms:*",
    "fsx:*",
    "gamelift:*",
    "globalaccelerator:*",
    "glue:*",
    "guardduty:*",
    "iam:*",
    "imagebuilder:*",
    "inspector:*",
    "iot:*",
    "iotsitewise:*",
    "iottwinmaker:*",
    "kendra:*",
    "kinesis:*",
    "kinesisanalytics:*",
    "kinesisvideo:*",
    "kms:*",
    "lambda:*",
    "lex:*",
    "lightsail:*",
    "logs:*",
    "machinelearning:*",
    "macie2:*",
    "mediaconvert:*",
    "medialive:*",
    "mediapackage:*",
    "mediastore:*",
    "mediatailor:*",
    "memorydb:*",
    "mgn:*",
    "mq:*",
    "kafka:*",
    "neptune-db:*",
    "networkmanager:*",
    "opensearch:*",
    "opsworks:*",
    "opsworks-cm:*",
    "sms-voice:*",
    "q:*",
    "pipes:*",
    "polly:*",
    "qldb:*",
    "quicksight:*",
    "rds:*",
    "redshift:*",
    "redshift-serverless:*",
    "rekognition:*",
    "resource-explorer-2:*",
    "resource-groups:*",
    "robomaker:*",
    "route53:*",
    "route53resolver:*",
    "s3:*",
    "sagemaker:*",
    "scheduler:*",
    "secretsmanager:*",
    "securityhub:*",
    "servicecatalog:*",
    "servicediscovery:*",
    "ses:*",
    "states:*",
    "signer:*",
    "sdb:*",
    "sns:*",
    "sqs:*",
    "ssm:*",
    "ssmmessages:*",
    "storagegateway:*",
    "transcribe:*",
    "transfer:*",
    "waf:*",
    "wafv2:*",
    "workspaces:*",
    "xray:*",
    # =====================================================
    # NDX ADDITIONS - Services added for sandbox scenarios
    # =====================================================
    # Textract - for document processing scenarios
    # Includes both sync and async operations for multi-page document processing
    # Sync operations (immediate response)
    "textract:AnalyzeDocument",
    "textract:AnalyzeExpense",
    "textract:AnalyzeID",
    "textract:DetectDocumentText",
    # Async operations (required for multi-page documents)
    "textract:StartDocumentAnalysis",
    "textract:StartDocumentTextDetection",
    "textract:StartExpenseAnalysis",
    "textract:StartLendingAnalysis",
    # Get results of async operations
    "textract:GetDocumentAnalysis",
    "textract:GetDocumentTextDetection",
    "textract:GetExpenseAnalysis",
    "textract:GetLendingAnalysis",
    "textract:GetLendingAnalysisSummary",
    # Adapter management (for custom models)
    "textract:GetAdapter",
    "textract:GetAdapterVersion",
    "textract:ListAdapters",
    "textract:ListAdapterVersions",
    "textract:ListTagsForResource",
  ]
}

# =============================================================================
# MODIFIED SCP: Limit Regions (with Bedrock inference profile exception)
# =============================================================================

resource "aws_organizations_policy" "limit_regions" {
  name        = "InnovationSandboxLimitRegionsScp"
  description = "SCP to limit use of AWS Regions. Includes Bedrock inference profile exception. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRegionAccess"
        Effect   = "Deny"
        Action   = ["*"]
        Resource = ["*"]
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.managed_regions
          }
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
            # Allow cross-region Bedrock inference profiles
            "bedrock:InferenceProfileArn" = "arn:aws:bedrock:*:*:inference-profile/*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "limit_regions" {
  policy_id = aws_organizations_policy.limit_regions.id
  target_id = var.sandbox_ou_id
}

# =============================================================================
# ENHANCED SCP: Cost Avoidance
# =============================================================================
# Comprehensive cost controls for sandbox environments
# See variables.tf for all configurable limits

resource "aws_organizations_policy" "cost_avoidance" {
  name        = "InnovationSandboxCostAvoidanceScp"
  description = "Comprehensive cost controls: EC2, RDS, EBS, ElastiCache, Lambda, and expensive services. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # =========================================================================
      # EC2 CONTROLS
      # =========================================================================
      [
        # Allow only specified EC2 instance types
        {
          Sid      = "DenyUnallowedEC2InstanceTypes"
          Effect   = "Deny"
          Action   = ["ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:instance/*"]
          Condition = {
            "ForAnyValue:StringNotLike" = {
              "ec2:InstanceType" = var.allowed_ec2_instance_types
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
        # Explicitly deny GPU/accelerated/very large instances
        {
          Sid      = "DenyGPUAndLargeInstances"
          Effect   = "Deny"
          Action   = ["ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:instance/*"]
          Condition = {
            "ForAnyValue:StringLike" = {
              "ec2:InstanceType" = var.denied_ec2_instance_types
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ],

      # =========================================================================
      # EBS CONTROLS
      # =========================================================================
      [
        # Deny expensive provisioned IOPS volume types (io1, io2)
        {
          Sid      = "DenyExpensiveEBSVolumeTypes"
          Effect   = "Deny"
          Action   = ["ec2:CreateVolume", "ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:volume/*"]
          Condition = {
            "ForAnyValue:StringEquals" = {
              "ec2:VolumeType" = var.denied_ebs_volume_types
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
        # Limit EBS volume size
        {
          Sid      = "DenyLargeEBSVolumes"
          Effect   = "Deny"
          Action   = ["ec2:CreateVolume", "ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:volume/*"]
          Condition = {
            NumericGreaterThan = {
              "ec2:VolumeSize" = tostring(var.max_ebs_volume_size_gb)
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ],

      # =========================================================================
      # RDS CONTROLS
      # =========================================================================
      [
        # Allow only specified RDS instance classes
        {
          Sid      = "DenyUnallowedRDSInstanceClasses"
          Effect   = "Deny"
          Action   = ["rds:CreateDBInstance", "rds:CreateDBCluster", "rds:ModifyDBInstance", "rds:ModifyDBCluster"]
          Resource = ["*"]
          Condition = {
            "ForAnyValue:StringNotLike" = {
              "rds:DatabaseClass" = var.allowed_rds_instance_classes
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ],

      # Conditionally deny Multi-AZ (doubles RDS cost)
      var.allow_rds_multi_az ? [] : [
        {
          Sid      = "DenyRDSMultiAZ"
          Effect   = "Deny"
          Action   = ["rds:CreateDBInstance", "rds:ModifyDBInstance"]
          Resource = ["*"]
          Condition = {
            Bool = {
              "rds:MultiAz" = "true"
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ],

      # Block RDS Read Replicas (each replica = additional instance cost)
      var.block_rds_read_replicas ? [
        {
          Sid      = "DenyRDSReadReplicas"
          Effect   = "Deny"
          Action   = ["rds:CreateDBInstanceReadReplica"]
          Resource = ["*"]
          Condition = {
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ] : [],

      # Block RDS Provisioned IOPS (very expensive - up to $0.10/IOPS-month)
      var.block_rds_provisioned_iops ? [
        {
          Sid      = "DenyRDSProvisionedIOPS"
          Effect   = "Deny"
          Action   = ["rds:CreateDBInstance", "rds:ModifyDBInstance"]
          Resource = ["*"]
          Condition = {
            NumericGreaterThan = {
              "rds:Piops" = "0"
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ] : [],

      # =========================================================================
      # ELASTICACHE CONTROLS
      # =========================================================================
      [
        # Allow only specified ElastiCache node types
        {
          Sid      = "DenyUnallowedElastiCacheNodeTypes"
          Effect   = "Deny"
          Action   = ["elasticache:CreateCacheCluster", "elasticache:CreateReplicationGroup", "elasticache:ModifyCacheCluster", "elasticache:ModifyReplicationGroup"]
          Resource = ["*"]
          Condition = {
            "ForAnyValue:StringNotEqualsIgnoreCase" = {
              "elasticache:CacheNodeType" = var.allowed_elasticache_node_types
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ],

      # =========================================================================
      # LAMBDA CONTROLS
      # =========================================================================
      var.block_lambda_provisioned_concurrency ? [
        {
          Sid      = "DenyLambdaProvisionedConcurrency"
          Effect   = "Deny"
          Action   = ["lambda:PutProvisionedConcurrencyConfig"]
          Resource = ["*"]
          Condition = {
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ] : [],

      # =========================================================================
      # EKS CONTROLS
      # =========================================================================
      [
        {
          Sid      = "LimitEKSNodegroupSize"
          Effect   = "Deny"
          Action   = ["eks:CreateNodegroup", "eks:UpdateNodegroupConfig"]
          Resource = ["*"]
          Condition = {
            NumericGreaterThan = {
              "eks:maxSize" = tostring(var.max_eks_nodegroup_size)
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ],

      # =========================================================================
      # AUTO SCALING CONTROLS
      # =========================================================================
      [
        # Limit Auto Scaling Group max size to prevent mass instance creation
        {
          Sid      = "LimitAutoScalingGroupSize"
          Effect   = "Deny"
          Action   = ["autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup"]
          Resource = ["*"]
          Condition = {
            NumericGreaterThan = {
              "autoscaling:MaxSize" = tostring(var.max_autoscaling_group_size)
            }
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ],

      # =========================================================================
      # EXPENSIVE SERVICES - COMPLETE BLOCKS
      # =========================================================================
      [
        # Original expensive services
        {
          Sid    = "DenyExpensiveManagedServices"
          Effect = "Deny"
          Action = [
            # SageMaker - ML endpoints and training are expensive
            "sagemaker:CreateEndpoint",
            "sagemaker:CreateEndpointConfig",
            "sagemaker:CreateTrainingJob",
            "sagemaker:CreateHyperParameterTuningJob",
            # EMR - big data clusters
            "elasticmapreduce:RunJobFlow",
            # GameLift - game server hosting
            "gamelift:CreateFleet",
            # Redshift - data warehouse clusters
            "redshift:CreateCluster",
          ]
          Resource = ["*"]
          Condition = {
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
        # Additional expensive services (configurable)
        {
          Sid      = "DenyAdditionalExpensiveServices"
          Effect   = "Deny"
          Action   = var.block_expensive_services
          Resource = ["*"]
          Condition = {
            ArnNotLike = {
              "aws:PrincipalARN" = local.exempt_role_arns
            }
          }
        },
      ]
    )
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "cost_avoidance" {
  policy_id = aws_organizations_policy.cost_avoidance.id
  target_id = coalesce(var.cost_avoidance_ou_id, var.sandbox_ou_id)
}
