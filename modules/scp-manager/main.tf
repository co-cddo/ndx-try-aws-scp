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
# NEW SCP: Cost Avoidance
# =============================================================================
# Restrict expensive services and large instance types

resource "aws_organizations_policy" "cost_avoidance" {
  count = var.enable_cost_avoidance ? 1 : 0

  name        = "InnovationSandboxCostAvoidanceScp"
  description = "SCP to prevent runaway costs by limiting instance sizes and expensive operations. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLargeEC2Instances"
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
      {
        Sid    = "DenyExpensiveServices"
        Effect = "Deny"
        Action = [
          # Expensive SageMaker operations
          "sagemaker:CreateEndpoint",
          "sagemaker:CreateEndpointConfig",
          "sagemaker:CreateTrainingJob",
          "sagemaker:CreateHyperParameterTuningJob",
          # Expensive EMR
          "elasticmapreduce:RunJobFlow",
          # GPU instances via specific services
          "gamelift:CreateFleet",
          # Large Redshift clusters
          "redshift:CreateCluster",
        ]
        Resource = ["*"]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      {
        Sid      = "LimitEKSNodegroupSize"
        Effect   = "Deny"
        Action   = ["eks:CreateNodegroup", "eks:UpdateNodegroupConfig"]
        Resource = ["*"]
        Condition = {
          "NumericGreaterThan" = {
            "eks:maxSize" = "5"
          }
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "cost_avoidance" {
  count = var.enable_cost_avoidance ? 1 : 0

  policy_id = aws_organizations_policy.cost_avoidance[0].id
  target_id = coalesce(var.cost_avoidance_ou_id, var.sandbox_ou_id)
}

# =============================================================================
# NEW SCP: IAM Workload Identity Protection
# =============================================================================
# Fills gaps NOT covered by existing InnovationSandboxProtectISBResourcesScp.
#
# EXISTING PROTECTION (InnovationSandboxProtectISBResourcesScp):
# - Already denies ALL actions on InnovationSandbox-ndx*, AWSReservedSSO*,
#   stacksets-exec-*, Isb-ndx* roles
#
# THIS SCP ADDS:
# - Block creating roles with Admin*/admin* patterns (privilege escalation)
# - Block iam:PassRole to privileged roles (prevent attaching to EC2/Lambda)
# - Block sts:AssumeRole to privileged roles (prevent direct assumption)
# - Block creating OrganizationAccountAccessRole, aws-service-role/*
#
# IMPORTANT: The Innovation Sandbox "SecurityAndIsolationRestrictions" SCP
# currently denies iam:CreateUser. To allow user creation, that SCP must be
# modified. Role creation (iam:CreateRole) is already allowed.

resource "aws_organizations_policy" "iam_workload_identity" {
  count = var.enable_iam_workload_identity ? 1 : 0

  name        = "InnovationSandboxIamWorkloadIdentityScp"
  description = "SCP to allow IAM role/user creation while preventing privilege escalation. MANAGED BY TERRAFORM."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # =======================================================================
      # DENY: Creating roles/users with admin patterns
      # =======================================================================
      # NOT covered by existing SCPs - prevents naming roles to look privileged
      {
        Sid    = "DenyCreatingAdminRoles"
        Effect = "Deny"
        Action = [
          "iam:CreateRole",
          "iam:CreateUser"
        ]
        Resource = [
          # Common admin role patterns - not covered by existing SCPs
          "arn:aws:iam::*:role/Admin*",
          "arn:aws:iam::*:role/admin*",
          "arn:aws:iam::*:user/Admin*",
          "arn:aws:iam::*:user/admin*",
          # OrganizationAccountAccessRole - could be used to escalate
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          # AWS service-linked roles - users shouldn't create directly
          "arn:aws:iam::*:role/aws-service-role/*",
          # AWSAccelerator roles - protect LZA infrastructure
          "arn:aws:iam::*:role/AWSAccelerator*",
          "arn:aws:iam::*:role/cdk-accel*"
        ]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalARN" = local.exempt_role_arns
          }
        }
      },
      # =======================================================================
      # DENY: Modifying admin-pattern roles
      # =======================================================================
      # Protect any Admin* roles that exist from tampering
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
      # =======================================================================
      # DENY: Passing privileged roles to services
      # =======================================================================
      # NOT covered by existing SCPs - prevent attaching privileged roles
      # to EC2 instances, Lambda functions, etc.
      {
        Sid    = "DenyPassingPrivilegedRoles"
        Effect = "Deny"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          # All privileged role patterns
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
      # =======================================================================
      # DENY: Assuming privileged roles
      # =======================================================================
      # NOT covered by existing SCPs - prevent users from assuming
      # privileged roles via sts:AssumeRole
      {
        Sid    = "DenyAssumingPrivilegedRoles"
        Effect = "Deny"
        Action = [
          "sts:AssumeRole"
        ]
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
