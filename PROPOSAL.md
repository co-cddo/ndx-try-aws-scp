# SCP Override Pattern for NDX Innovation Sandbox

## The Problem

The Innovation Sandbox comes with SCPs (Service Control Policies) that are too restrictive for some of the NDX scenarios:

1. **Textract is blocked** - The FOI Redaction and document processing scenarios need Textract, but it's not in the allowlist because AWS Nuke can't clean up Textract resources.

2. **Bedrock cross-region inference doesn't work** - The region-lock SCP blocks calls to models in other regions, but Bedrock's inference profiles need cross-region access.

3. **ECS can't access Secrets Manager** - The LocalGov Drupal scenario fails because ECS tasks can't pull database credentials from Secrets Manager.

4. **No cost controls** - Users could spin up expensive resources (large EC2s, SageMaker endpoints) and blow through budgets before the 24-hour billing reconciliation catches it.

Additionally, there's a conflict with LZA - it has an EventBridge rule that reverts any SCP changes we make manually.

## Why We Can't Just Edit the SCPs in the Console

- Manual changes get overwritten by LZA
- No audit trail or version control
- Can't easily roll back if something breaks
- Multiple people might make conflicting changes

## The Solution

A Terraform module that:

1. **Takes ownership of two existing SCPs** (via import):
   - `InnovationSandboxAwsNukeSupportedServicesScp` - we add Textract to the allowlist
   - `InnovationSandboxLimitRegionsScp` - we add an exception for Bedrock inference profiles

2. **Creates one new SCP**:
   - `InnovationSandboxCostAvoidanceScp` - limits EC2 instance types, blocks expensive services

## What Changes

### Textract Access
Before: All Textract actions denied
After: Read-only Textract operations allowed (AnalyzeDocument, DetectDocumentText, etc.)

### Bedrock Cross-Region
Before: All actions outside us-east-1/us-west-2 denied
After: Same, but with exception for `bedrock:InferenceProfileArn`

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

# Still needed:
# 1. Import existing SCPs
AWS_PROFILE=ndx-management ../../scripts/import-existing-scps.sh

# 2. Review changes
AWS_PROFILE=ndx-management terraform plan

# 3. Apply
AWS_PROFILE=ndx-management terraform apply
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| CDK redeploy overwrites our changes | Don't redeploy ISB Account Pool stack; or re-run Terraform after |
| LZA reverts SCP attachments | Need to set `scpRevertChangesConfig.enable: false` in LZA config |
| Cost controls too restrictive | Instance types are configurable in terraform.tfvars |

## Still TODO

1. **LZA config change** - Need to disable the SCP revert rule permanently
2. **ECS/Secrets Manager fix** - Need to investigate which SCP is blocking this and add an exception
3. **Testing** - Run through each scenario after applying to verify they work

## Questions for Chris

1. Are the default EC2 instance types reasonable? (t2/t3 micro-large, m5/m6i large-xlarge)
2. Should we block any other expensive services?
3. Where should this repo live long-term? (CDDO org? Separate?)
