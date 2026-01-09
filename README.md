# NDX Innovation Sandbox - SCP Override Pattern

Terraform module to manage and override Service Control Policies (SCPs) for the NDX Innovation Sandbox deployment.

---

## Meeting Notes: January 2025 Investigation

### What Was Broken

| Issue | Symptom | Root Cause |
|-------|---------|------------|
| **Textract blocked** | FOI Redaction scenario fails on multi-page documents | Async operations (`StartDocumentAnalysis`, etc.) missing from allowlist - only sync operations were permitted |
| **ECS can't access Secrets Manager** | LocalGov Drupal fails: "explicit deny in service control policy" | **Not a Secrets Manager issue** - the `LimitRegions` SCP blocks ALL actions outside us-east-1/us-west-2. UK scenarios deploy in eu-west-2 → everything blocked |
| **Bedrock cross-region** | Inference profiles fail | Already fixed in live SCP - `bedrock:InferenceProfileArn` exception exists |
| **No cost controls** | Users could spin up expensive resources | No SCP existed to limit instance sizes or block expensive services |

### What Each Fix Does

#### 1. Textract Async Operations
**File**: `modules/scp-manager/main.tf` (nuke_supported_services)

The `InnovationSandboxAwsNukeSupportedServicesScp` uses a "deny NotAction" pattern - services in the list are ALLOWED. We added:
```
textract:StartDocumentAnalysis      # Async analysis (multi-page)
textract:StartDocumentTextDetection # Async text detection
textract:StartExpenseAnalysis       # Async expense docs
textract:StartLendingAnalysis       # Async lending docs
textract:GetDocumentAnalysis        # Get async results
textract:GetDocumentTextDetection
textract:GetExpenseAnalysis
textract:GetLendingAnalysis
textract:GetLendingAnalysisSummary
```

**Why it was broken**: Sync operations (immediate response) were allowed, but async operations (required for documents >1 page) were not.

#### 2. EU-West-2 Region Access
**File**: `.github/workflows/terraform.yaml` (TF_VAR_managed_regions)

Added `eu-west-2` to the allowed regions list:
```yaml
TF_VAR_managed_regions: '["us-east-1", "us-west-2", "eu-west-2"]'
```

**Why it was broken**: The `LimitRegions` SCP blocks ALL AWS actions outside allowed regions. UK-based scenarios (LocalGov Drupal) deploy to eu-west-2, so they couldn't do anything - not just Secrets Manager, but EC2, RDS, everything.

#### 3. Cost Avoidance SCP (NEW)
**File**: `modules/scp-manager/main.tf` (cost_avoidance)

Creates `InnovationSandboxCostAvoidanceScp` that:
- Limits EC2 to: t2/t3/t3a (micro→large), m5/m6i (large→xlarge)
- Blocks expensive operations:
  - `sagemaker:CreateEndpoint`, `CreateTrainingJob`
  - `elasticmapreduce:RunJobFlow`
  - `redshift:CreateCluster`
  - `gamelift:CreateFleet`
- Limits EKS nodegroups to max 5 nodes

**Why needed**: No guardrails existed. Users could spin up p4d.24xlarge GPU instances or SageMaker endpoints and blow through budgets before 24-hour billing reconciliation.

### OU Structure (Important Context)

```
InnovationSandbox (ou-2laj-lha5vsam)     ← Parent OU, NO SCPs here
  └── ndx_InnovationSandboxAccountPool (ou-2laj-4dyae1oa)  ← SCPs attached HERE
        ├── Entry      (WriteProtection)
        ├── Available  (WriteProtection)
        ├── Active     (FullAWSAccess only - running sandboxes)
        ├── Frozen
        ├── Exit       (WriteProtection)
        ├── CleanUp    (WriteProtection)
        └── Quarantine (WriteProtection)
```

We target `ou-2laj-4dyae1oa` (the AccountPool), not the parent.

### Next Steps to Complete

| Step | Who | Notes |
|------|-----|-------|
| **1. Create GitHub production environment** | Greg/Chris | Repo Settings → Environments → New → "production" → Add required reviewers |
| **2. Review Terraform plan** | Chris | Run `terraform plan` to see exact changes |
| **3. Disable LZA SCP revert** | Platform team | Set `scpRevertChangesConfig.enable: false` in LZA config, otherwise changes will be reverted automatically |
| **4. Apply Terraform** | Manual trigger | Actions → Terraform SCP Management → Run workflow → Select "apply" |
| **5. Test scenarios** | Greg | Run through Textract, LocalGov Drupal, Bedrock after apply |

### Pipeline Security

- **No stored credentials** - Uses OIDC (GitHub proves identity to AWS)
- **Manual apply only** - Never auto-applies on merge
- **Environment gate** - Apply requires approval from configured reviewers
- **Fork protection** - PRs from forks cannot run the workflow

---

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
