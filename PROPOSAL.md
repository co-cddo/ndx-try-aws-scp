# SCP Override Pattern for NDX Innovation Sandbox

## The Problem

The Innovation Sandbox comes with SCPs (Service Control Policies) that are too restrictive for some of the NDX scenarios:

1. **Textract is blocked** - The FOI Redaction and document processing scenarios need Textract, but it's not in the allowlist because AWS Nuke can't clean up Textract resources.

2. **Bedrock cross-region inference doesn't work** - The region-lock SCP blocks calls to models in other regions, but Bedrock's inference profiles need cross-region access.

3. **ECS can't access Secrets Manager** - The LocalGov Drupal scenario fails because ECS tasks can't pull database credentials from Secrets Manager.

4. **No cost controls** - Users could spin up expensive resources (large EC2s, SageMaker endpoints) and blow through budgets before the 24-hour billing reconciliation catches it.

Additionally, there's a conflict with LZA - it has an EventBridge rule that reverts any SCP changes we make manually.

## Investigation Findings (January 2025)

After analyzing the current SCPs attached to `ou-2laj-4dyae1oa` (ndx_InnovationSandboxAccountPool):

| Issue | Status | Finding |
|-------|--------|---------|
| **Textract** | Partially fixed | Read operations (AnalyzeDocument, etc.) already in allowlist. **Missing async operations** (StartDocumentAnalysis, etc.) needed for multi-page documents. |
| **Bedrock cross-region** | Already fixed | LimitRegionsScp already has `bedrock:InferenceProfileArn` exception |
| **ECS/Secrets Manager** | NOT an SCP issue | Both `ecs:*` and `secretsmanager:*` are in NukeSupportedServices allowlist. Issue is likely IAM permissions, VPC endpoints, or task execution role config |
| **Cost controls** | New SCP needed | Will create `InnovationSandboxCostAvoidanceScp` |

### OU Structure

```
InnovationSandbox (ou-2laj-lha5vsam) - Parent OU, no SCPs
  └── ndx_InnovationSandboxAccountPool (ou-2laj-4dyae1oa) - SCPs attached here
        ├── Entry
        ├── Available
        ├── Exit
        ├── CleanUp
        └── Quarantine
```

## The Solution

A Terraform module that:

1. **Takes ownership of two existing SCPs** (via import):
   - `InnovationSandboxAwsNukeSupportedServicesScp` - adds async Textract operations
   - `InnovationSandboxLimitRegionsScp` - Bedrock exception already present

2. **Creates one new SCP**:
   - `InnovationSandboxCostAvoidanceScp` - limits EC2 instance types, blocks expensive services

## What Changes

### Textract Access
Before: Only sync Textract operations allowed
After: Both sync and async operations allowed:
- `StartDocumentAnalysis`, `StartDocumentTextDetection`
- `StartExpenseAnalysis`, `StartLendingAnalysis`

### Bedrock Cross-Region
**No changes needed** - exception already in place for `bedrock:InferenceProfileArn`

### Cost Controls (New)
- EC2 limited to t2/t3/m5/m6i up to xlarge
- Blocks: SageMaker endpoints, EMR clusters, Redshift clusters
- EKS nodegroups limited to 5 nodes max

## File Structure

```
terraform-scp-overrides/
├── modules/scp-manager/     # The reusable module
│   ├── main.tf              # SCP definitions
│   ├── variables.tf         # Configurable inputs
│   └── outputs.tf
├── environments/ndx-production/
│   ├── main.tf              # Calls the module
│   ├── variables.tf
│   ├── terraform.tfvars     # Actual values (OU IDs, etc.)
│   └── backend.tf           # S3 state backend
└── scripts/
    ├── bootstrap-backend.sh # Creates S3 bucket + DynamoDB for state
    └── import-existing-scps.sh # Imports existing SCPs into TF state
```

## How to Deploy

```bash
# Already done:
# 1. S3 bucket and DynamoDB table created for state
# 2. Terraform initialized
# 3. SCPs imported into state

# To apply (via GitHub Actions):
# 1. Merge fix branches to main
# 2. Pipeline runs plan automatically
# 3. After approval, pipeline applies changes
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| CDK redeploy overwrites our changes | Don't redeploy ISB Account Pool stack; or re-run Terraform after |
| LZA reverts SCP attachments | Need to set `scpRevertChangesConfig.enable: false` in LZA config |
| Cost controls too restrictive | Instance types are configurable via TF_VAR_allowed_ec2_instance_types |

## Still TODO

1. **LZA config change** - Need to disable the SCP revert rule permanently
2. **ECS/Secrets Manager investigation** - Not an SCP issue; check IAM task execution role and VPC endpoints
3. **Testing** - Run through each scenario after applying to verify they work

## Questions for Chris

1. Are the default EC2 instance types reasonable? (t2/t3 micro-large, m5/m6i large-xlarge)
2. Should we block any other expensive services?
3. Where should this repo live long-term? (CDDO org? Separate?)
