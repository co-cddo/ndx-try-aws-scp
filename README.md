# NDX Innovation Sandbox - SCP Override Pattern

Terraform module to manage and override Service Control Policies (SCPs) for the NDX Innovation Sandbox deployment.

## Problem Statement

The Innovation Sandbox on AWS (ISB) deploys SCPs via CDK/CloudFormation. We need to:
1. **Relax** some restrictions (add Textract, Bedrock inference profiles, Secrets Manager for ECS)
2. **Add** new restrictions (cost avoidance - limit instance sizes)

SCPs use AND logic - you cannot make things MORE permissive by adding new SCPs. Therefore, we must **modify** the existing SCPs for relaxation, and can **add** new SCPs for restrictions.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Organizations                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Sandbox OU                                ││
│  │  ┌─────────────────────────────────────────────────────────┐││
│  │  │ ISB-Deployed SCPs (CDK)        Our SCPs (Terraform)     │││
│  │  │ ─────────────────────          ───────────────────────  │││
│  │  │ • NukeSupportedServices  ←──── MODIFIED (add textract)  │││
│  │  │ • Restrictions           ←──── MODIFIED (secrets mgr)   │││
│  │  │ • ProtectISBResources          (unchanged)              │││
│  │  │ • LimitRegions           ←──── MODIFIED (bedrock)       │││
│  │  │ • WriteProtection              (unchanged)              │││
│  │  │                                                         │││
│  │  │                          ←──── NEW: CostAvoidance       │││
│  │  └─────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## SCPs Managed

| SCP | Action | Purpose |
|-----|--------|---------|
| InnovationSandboxAwsNukeSupportedServicesScp | MODIFY | Add Textract, fix Secrets Manager |
| InnovationSandboxLimitRegionsScp | MODIFY | Add Bedrock inference profile exception |
| InnovationSandboxCostAvoidanceScp | CREATE | Limit EC2 instance sizes, expensive services |

## Usage

### Prerequisites

1. AWS CLI configured with Organizations admin access
2. Terraform >= 1.5
3. Know your SCP Policy IDs (from AWS Organizations console)

### Find SCP Policy IDs

```bash
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --query 'Policies[?starts_with(Name, `InnovationSandbox`)].{Name:Name,Id:Id}'
```

### Import Existing SCPs

Before Terraform can manage ISB-created SCPs, import them:

```bash
cd environments/ndx-production
terraform init

# Import each SCP (get IDs from above command)
terraform import aws_organizations_policy.nuke_supported_services p-xxxxxxxxx
terraform import aws_organizations_policy.limit_regions p-yyyyyyyyy
```

### Deploy

```bash
terraform plan
terraform apply
```

## File Structure

```
terraform-scp-overrides/
├── README.md
├── modules/
│   └── scp-manager/
│       ├── main.tf           # SCP resources
│       ├── variables.tf      # Input variables
│       └── outputs.tf        # Output values
├── policies/
│   ├── nuke-supported-services.json      # Modified allowlist
│   ├── limit-regions.json                # Region restrictions + Bedrock
│   └── cost-avoidance.json               # NEW: Instance size limits
└── environments/
    └── ndx-production/
        ├── main.tf           # Environment config
        ├── variables.tf
        ├── terraform.tfvars  # Environment-specific values
        └── backend.tf        # State backend config
```

## Conflict with ISB CDK

**Important**: ISB CDK creates and "owns" the original SCPs. When you modify them via Terraform:

1. ISB CDK will show drift on next `cdk diff`
2. Running `cdk deploy` may revert your changes
3. **Mitigation**: Don't run ISB CDK deploy on the Account Pool stack after Terraform changes

### Recommended Workflow

1. Deploy ISB via CDK (initial setup)
2. Import SCPs into Terraform
3. Make SCP changes via Terraform only
4. If ISB CDK update is needed:
   - Plan the CDK deploy
   - Re-apply Terraform after CDK

## LZA Conflict

LZA (Landing Zone Accelerator) has an EventBridge rule that reverts SCP changes:
`AWSAccelerator-FinalizeSt-RevertScpChangesModifyScp-*`

**Fix**: Set in LZA `security-config.yaml`:
```yaml
scpRevertChangesConfig:
  enable: false
```

## Namespace

The ISB uses `ndx` as namespace. All role ARN patterns use this:
- `arn:aws:iam::*:role/InnovationSandbox-ndx*`
- `arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*AWSReservedSSO_ndx_IsbAdmins*`
