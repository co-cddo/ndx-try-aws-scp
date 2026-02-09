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

  # Default EC2 instance types - DRY: single source of truth
  default_ec2_instance_types = [
    "t2.micro", "t2.small", "t2.medium",
    "t3.micro", "t3.small", "t3.medium", "t3.large",
    "t3a.micro", "t3a.small", "t3a.medium", "t3a.large",
    "m5.large", "m5.xlarge",
    "m6i.large", "m6i.xlarge"
  ]

  # Use provided list or fall back to default
  allowed_ec2_instance_types = coalesce(var.allowed_ec2_instance_types, local.default_ec2_instance_types)
}

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

resource "aws_organizations_policy_attachment" "nuke_supported_services" {
  policy_id = aws_organizations_policy.nuke_supported_services.id
  target_id = var.sandbox_ou_id
}

locals {
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
    # Textract
    "textract:AnalyzeDocument",
    "textract:AnalyzeExpense",
    "textract:AnalyzeID",
    "textract:DetectDocumentText",
    "textract:StartDocumentAnalysis",
    "textract:StartDocumentTextDetection",
    "textract:StartExpenseAnalysis",
    "textract:StartLendingAnalysis",
    "textract:GetDocumentAnalysis",
    "textract:GetDocumentTextDetection",
    "textract:GetExpenseAnalysis",
    "textract:GetLendingAnalysis",
    "textract:GetLendingAnalysisSummary",
    "textract:GetAdapter",
    "textract:GetAdapterVersion",
    "textract:ListAdapters",
    "textract:ListAdapterVersions",
    "textract:ListTagsForResource",
  ]
}

# Cost Avoidance SCPs - split into two due to AWS 5,120 char limit

resource "aws_organizations_policy" "cost_avoidance_compute" {
  count = var.enable_cost_avoidance ? 1 : 0

  name        = "InnovationSandboxCostAvoidanceComputeScp"
  description = "Cost controls for compute: EC2, EBS, RDS, ElastiCache, EKS, ASG. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "DenyUnallowedEC2"
          Effect   = "Deny"
          Action   = ["ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:instance/*"]
          Condition = {
            "ForAnyValue:StringNotLike" = {
              "ec2:InstanceType" = local.allowed_ec2_instance_types
            }
            ArnNotLike = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
        {
          Sid      = "DenyExpensiveEC2"
          Effect   = "Deny"
          Action   = ["ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:instance/*"]
          Condition = {
            "ForAnyValue:StringLike" = {
              "ec2:InstanceType" = var.denied_ec2_instance_types
            }
            ArnNotLike = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
      ],

      [
        {
          Sid      = "DenyExpensiveEBS"
          Effect   = "Deny"
          Action   = ["ec2:CreateVolume", "ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:volume/*"]
          Condition = {
            "ForAnyValue:StringEquals" = { "ec2:VolumeType" = var.denied_ebs_volume_types }
            ArnNotLike                 = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
        {
          Sid      = "DenyLargeEBS"
          Effect   = "Deny"
          Action   = ["ec2:CreateVolume", "ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:volume/*"]
          Condition = {
            NumericGreaterThan = { "ec2:VolumeSize" = tostring(var.max_ebs_volume_size_gb) }
            ArnNotLike         = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
      ],

      [
        {
          Sid      = "DenyUnallowedRDS"
          Effect   = "Deny"
          Action   = ["rds:CreateDBInstance", "rds:CreateDBCluster", "rds:ModifyDBInstance", "rds:ModifyDBCluster"]
          Resource = ["*"]
          Condition = {
            "ForAnyValue:StringNotLike" = { "rds:DatabaseClass" = var.allowed_rds_instance_classes }
            ArnNotLike                  = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
      ],

      var.allow_rds_multi_az ? [] : [
        {
          Sid      = "DenyRDSMultiAZ"
          Effect   = "Deny"
          Action   = ["rds:CreateDBInstance", "rds:ModifyDBInstance"]
          Resource = ["*"]
          Condition = {
            Bool       = { "rds:MultiAz" = "true" }
            ArnNotLike = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
      ],

      [
        {
          Sid      = "DenyUnallowedCache"
          Effect   = "Deny"
          Action   = ["elasticache:CreateCacheCluster", "elasticache:CreateReplicationGroup"]
          Resource = ["*"]
          Condition = {
            "ForAnyValue:StringNotEqualsIgnoreCase" = { "elasticache:CacheNodeType" = var.allowed_elasticache_node_types }
            ArnNotLike                              = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
      ],

      [
        {
          Sid      = "LimitEKSSize"
          Effect   = "Deny"
          Action   = ["eks:CreateNodegroup", "eks:UpdateNodegroupConfig"]
          Resource = ["*"]
          Condition = {
            NumericGreaterThan = { "eks:maxSize" = tostring(var.max_eks_nodegroup_size) }
            ArnNotLike         = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
        {
          Sid      = "LimitASGSize"
          Effect   = "Deny"
          Action   = ["autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup"]
          Resource = ["*"]
          Condition = {
            NumericGreaterThan = { "autoscaling:MaxSize" = tostring(var.max_autoscaling_group_size) }
            ArnNotLike         = { "aws:PrincipalARN" = local.exempt_role_arns }
          }
        },
      ],

      var.block_lambda_provisioned_concurrency ? [
        {
          Sid       = "DenyLambdaPC"
          Effect    = "Deny"
          Action    = ["lambda:PutProvisionedConcurrencyConfig"]
          Resource  = ["*"]
          Condition = { ArnNotLike = { "aws:PrincipalARN" = local.exempt_role_arns } }
        },
      ] : []
    )
  })

  tags = var.tags
}

resource "aws_organizations_policy" "cost_avoidance_services" {
  count = var.enable_cost_avoidance ? 1 : 0

  name        = "InnovationSandboxCostAvoidanceServicesScp"
  description = "Block expensive services: SageMaker, EMR, Redshift, Neptune, etc. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyExpensiveML"
        Effect = "Deny"
        Action = [
          "sagemaker:CreateEndpoint",
          "sagemaker:CreateEndpointConfig",
          "sagemaker:CreateTrainingJob",
          "sagemaker:CreateHyperParameterTuningJob",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "DenyExpensiveData"
        Effect = "Deny"
        Action = [
          "elasticmapreduce:RunJobFlow",
          "redshift:CreateCluster",
          "gamelift:CreateFleet",
        ]
        Resource = ["*"]
      },
      {
        Sid      = "DenyExpensiveServices"
        Effect   = "Deny"
        Action   = var.block_expensive_services
        Resource = ["*"]
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "cost_avoidance_compute" {
  count = var.enable_cost_avoidance ? 1 : 0

  policy_id = aws_organizations_policy.cost_avoidance_compute[0].id
  target_id = coalesce(var.cost_avoidance_ou_id, var.sandbox_ou_id)
}

resource "aws_organizations_policy_attachment" "cost_avoidance_services" {
  count = var.enable_cost_avoidance ? 1 : 0

  policy_id = aws_organizations_policy.cost_avoidance_services[0].id
  target_id = coalesce(var.cost_avoidance_ou_id, var.sandbox_ou_id)
}

resource "aws_organizations_policy" "iam_workload_identity" {
  count = var.enable_iam_workload_identity ? 1 : 0

  name        = "InnovationSandboxIamWorkloadIdentityScp"
  description = "SCP to allow IAM role/user creation while preventing privilege escalation. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCreatingAdminRoles"
        Effect = "Deny"
        Action = ["iam:CreateRole", "iam:CreateUser"]
        Resource = [
          "arn:aws:iam::*:role/Admin*",
          "arn:aws:iam::*:role/admin*",
          "arn:aws:iam::*:user/Admin*",
          "arn:aws:iam::*:user/admin*",
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          "arn:aws:iam::*:role/aws-service-role/*",
          "arn:aws:iam::*:role/AWSAccelerator*",
          "arn:aws:iam::*:role/cdk-accel*"
        ]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid    = "DenyModifyingAdminRoles"
        Effect = "Deny"
        Action = [
          "iam:DeleteRole",
          "iam:DeleteUser",
          "iam:UpdateRole",
          "iam:UpdateUser",
          "iam:UpdateAssumeRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:PutRolePermissionsBoundary",
          "iam:DeleteRolePermissionsBoundary"
        ]
        Resource = [
          "arn:aws:iam::*:role/Admin*",
          "arn:aws:iam::*:role/admin*",
          "arn:aws:iam::*:user/Admin*",
          "arn:aws:iam::*:user/admin*",
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          "arn:aws:iam::*:role/AWSAccelerator*",
          "arn:aws:iam::*:role/cdk-accel*"
        ]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid    = "DenyPassingPrivilegedRoles"
        Effect = "Deny"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::*:role/InnovationSandbox*",
          "arn:aws:iam::*:role/aws-reserved/*",
          "arn:aws:iam::*:role/stacksets-exec-*",
          "arn:aws:iam::*:role/AWSControlTowerExecution",
          "arn:aws:iam::*:role/AWSControlTower*",
          "arn:aws:iam::*:role/aws-service-role/*",
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          "arn:aws:iam::*:role/AWSAccelerator*",
          "arn:aws:iam::*:role/cdk-accel*",
          "arn:aws:iam::*:role/Admin*",
          "arn:aws:iam::*:role/admin*"
        ]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid    = "DenyAssumingPrivilegedRoles"
        Effect = "Deny"
        Action = ["sts:AssumeRole"]
        Resource = [
          "arn:aws:iam::*:role/InnovationSandbox*",
          "arn:aws:iam::*:role/aws-reserved/*",
          "arn:aws:iam::*:role/stacksets-exec-*",
          "arn:aws:iam::*:role/AWSControlTowerExecution",
          "arn:aws:iam::*:role/AWSControlTower*",
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          "arn:aws:iam::*:role/AWSAccelerator*",
          "arn:aws:iam::*:role/cdk-accel*",
          "arn:aws:iam::*:role/Admin*",
          "arn:aws:iam::*:role/admin*"
        ]
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

resource "aws_organizations_policy_attachment" "iam_workload_identity" {
  count = var.enable_iam_workload_identity ? 1 : 0

  policy_id = aws_organizations_policy.iam_workload_identity[0].id
  target_id = var.sandbox_ou_id
}

resource "aws_organizations_policy" "restrictions" {
  name        = "InnovationSandboxRestrictionsScp"
  description = "SCP for security, isolation, and region restrictions. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyRegionAccess"
        Effect    = "Deny"
        NotAction = ["bedrock:*"]
        Resource  = ["*"]
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.managed_regions
          }
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid    = "DenyExpensiveBedrockModels"
        Effect = "Deny"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Converse",
          "bedrock:ConverseStream"
        ]
        Resource = var.denied_bedrock_model_patterns
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid    = "SecurityAndIsolationRestrictions"
        Effect = "Deny"
        Action = [
          "aws-portal:ModifyAccount",
          "aws-portal:ViewAccount",
          "cloudtrail:CreateServiceLinkedChannel",
          "cloudtrail:UpdateServiceLinkedChannel",
          "networkmanager:AssociateTransitGatewayConnectPeer",
          "networkmanager:DisassociateTransitGatewayConnectPeer",
          "networkmanager:StartOrganizationServiceAccessUpdate",
          "ram:CreateResourceShare",
          "ram:EnableSharingWithAwsOrganization",
          "ssm:ModifyDocumentPermission",
          "wafv2:DisassociateFirewallManager",
          "wafv2:PutFirewallManagerRuleGroups",
          "cloudtrail:LookupEvents"
        ]
        Resource = ["*"]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid    = "CostImplicationRestrictions"
        Effect = "Deny"
        Action = [
          "aws-portal:ModifyBilling",
          "aws-portal:ModifyPaymentMethods",
          "ce:CreateAnomalyMonitor",
          "ce:CreateAnomalySubscription",
          "ce:CreateCostCategoryDefinition",
          "ce:CreateNotificationSubscription",
          "ce:CreateReport",
          "ce:UpdatePreferences",
          "devicefarm:Purchase*",
          "devicefarm:RenewOffering",
          "dynamodb:Purchase*",
          "ec2:AcceptReservedInstancesExchangeQuote",
          "ec2:EnableIpamOrganizationAdminAccount",
          "ec2:ModifyReservedInstances",
          "ec2:Purchase*",
          "elasticache:Purchase*",
          "es:Purchase*",
          "glacier:Purchase*",
          "mediaconnect:Purchase*",
          "medialive:Purchase*",
          "rds:Purchase*",
          "redshift:Purchase*",
          "shield:AssociateDRTRole",
          "shield:CreateProtection",
          "shield:CreateSubscription",
          "shield:UpdateEmergencyContactSettings"
        ]
        Resource = ["*"]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid    = "OperationalRestrictions"
        Effect = "Deny"
        Action = [
          "account:EnableRegion",
          "auditmanager:DeregisterOrganizationAdminAccount",
          "auditmanager:RegisterOrganizationAdminAccount",
          "backup:PutBackupVaultLockConfiguration",
          "cassandra:UpdatePartitioner",
          "chime:*",
          "cloudhsm:*",
          "deepcomposer:AssociateCoupon",
          "directconnect:AllocateConnectionOnInterconnect",
          "directconnect:AllocateHostedConnection",
          "directconnect:AssociateHostedConnection",
          "directconnect:CreateInterconnect",
          "drs:CreateExtendedSourceServer",
          "elasticache:PurchaseReservedCacheNodesOffering",
          "events:CreatePartnerEventSource",
          "glacier:AbortVaultLock",
          "glacier:CompleteVaultLock",
          "glacier:InitiateVaultLock",
          "glacier:SetVaultAccessPolicy",
          "iotevents:PutLoggingOptions",
          "iotsitewise:CreateBulkImportJob",
          "lambda:CreateCodeSigningConfig",
          "license-manager:CreateLicenseConversionTaskForResource",
          "macie2:UpdateOrganizationConfiguration",
          "mediaConvert:CreateQueue",
          "medialive:ClaimDevice",
          "mgn:*",
          "robomaker:CreateDeploymentJob",
          "robomaker:CreateFleet",
          "robomaker:CreateRobot",
          "robomaker:DeregisterRobot",
          "robomaker:RegisterRobot",
          "robomaker:SyncDeploymentJob",
          "robomaker:UpdateRobotDeployment",
          "route53domains:*",
          "s3-object-lambda:PutObjectLegalHold",
          "s3-object-lambda:PutObjectRetention",
          "s3:PutObjectLegalHold",
          "ses:PutDeliverabilityDashboardOption",
          "storagegateway:*",
          "wam:*",
          "wellarchitected:UpdateGlobalSettings",
          "workmail:AssumeImpersonationRole",
          "workmail:CreateImpersonationRole",
          "workmail:UpdateImpersonationRole",
          "workspaces:ModifyAccount"
        ]
        Resource = ["*"]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      }
    ]
  })

  tags = var.tags

  lifecycle {
    # Prevent accidental destruction of this critical SCP
    prevent_destroy = true
  }
}

resource "aws_organizations_policy_attachment" "restrictions" {
  policy_id = aws_organizations_policy.restrictions.id
  target_id = var.sandbox_ou_id
}
