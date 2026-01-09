# GitHub Actions Setup for Terraform SCP Management

This document explains how to set up the GitHub Actions pipeline for automated Terraform deployments.

## How It Works

1. **On Pull Request**: Runs `terraform plan` and comments the output on the PR
2. **On Merge to Main**: Runs `terraform apply` (requires approval)
3. **Manual Trigger**: Can run plan or apply via workflow dispatch

No AWS credentials are stored in GitHub. We use OIDC (OpenID Connect) - GitHub proves its identity to AWS, and AWS gives temporary credentials.

## Setup Steps

### 1. Create the IAM OIDC Provider (one-time)

In the **management account** (955063685555), check if the GitHub OIDC provider exists:

```bash
aws iam list-open-id-connect-providers
```

If not, create it:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create the IAM Role

Create a role that GitHub Actions can assume. Save this as `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::955063685555:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"
        }
      }
    }
  ]
}
```

**Important**: Replace `OWNER/REPO` with the actual repo (e.g., `gjarzebak95/ndx-scp-overrides` or wherever this ends up living).

Create the role:

```bash
aws iam create-role \
  --role-name GitHubActions-NDX-SCPDeploy \
  --assume-role-policy-document file://trust-policy.json \
  --description "Role for GitHub Actions to deploy SCP changes"
```

### 3. Attach Permissions

The role needs permission to manage SCPs and access the Terraform state:

```bash
# Create the policy
aws iam create-policy \
  --policy-name GitHubActions-NDX-SCPDeploy-Policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "OrganizationsSCP",
        "Effect": "Allow",
        "Action": [
          "organizations:ListPolicies",
          "organizations:DescribePolicy",
          "organizations:CreatePolicy",
          "organizations:UpdatePolicy",
          "organizations:DeletePolicy",
          "organizations:AttachPolicy",
          "organizations:DetachPolicy",
          "organizations:ListTargetsForPolicy",
          "organizations:ListPoliciesForTarget",
          "organizations:DescribeOrganization",
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:DescribeOrganizationalUnit"
        ],
        "Resource": "*"
      },
      {
        "Sid": "TerraformState",
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::ndx-terraform-state-955063685555",
          "arn:aws:s3:::ndx-terraform-state-955063685555/*"
        ]
      },
      {
        "Sid": "TerraformLocking",
        "Effect": "Allow",
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        "Resource": "arn:aws:dynamodb:eu-west-2:955063685555:table/ndx-terraform-locks"
      }
    ]
  }'

# Attach to role
aws iam attach-role-policy \
  --role-name GitHubActions-NDX-SCPDeploy \
  --policy-arn arn:aws:iam::955063685555:policy/GitHubActions-NDX-SCPDeploy-Policy
```

### 4. Configure GitHub Repository

1. Go to the repo → Settings → Secrets and variables → Actions

2. Add a **Repository Secret**:
   - Name: `AWS_ROLE_ARN`
   - Value: `arn:aws:iam::955063685555:role/GitHubActions-NDX-SCPDeploy`

3. Create a **production** environment:
   - Go to Settings → Environments → New environment
   - Name: `production`
   - Add required reviewers (Chris, etc.)
   - This ensures `terraform apply` requires approval

## Usage

### Automatic (Recommended)

- Create a PR with changes → Plan runs automatically, results posted as comment
- Merge PR → Apply runs after approval

### Manual

- Go to Actions → Terraform SCP Management → Run workflow
- Select `plan` or `apply`

## Security Notes

- Fork PRs are blocked from running the workflow
- The IAM role only trusts the specific repo
- Apply requires environment approval
- No long-lived credentials stored anywhere
- State is encrypted in S3
