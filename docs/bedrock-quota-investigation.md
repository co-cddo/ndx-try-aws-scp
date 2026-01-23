# Bedrock Quota Investigation - Account 449788867583 (pool-001)

**Date:** 2026-01-21 (Updated: 2026-01-23)
**Investigator:** Gerard Jarzebak
**Issue:** Bedrock queries (Nova Pro) being blocked with "Too many tokens per day" error

---

## Executive Summary

Sandbox account `449788867583` (pool-001) has **zero Bedrock quotas** for on-demand model inference, causing all Nova Pro API calls to fail with `ThrottlingException`.

**This is NOT a "new account" issue** - pool-001 is the **oldest** sandbox pool account (created 2025-11-07), and newer pool accounts work fine. This suggests an **account-specific issue** that requires AWS Support investigation.

---

## Key Finding: Pool-001 is an Outlier

| Account | Name | Created | Bedrock Status |
|---------|------|---------|----------------|
| **449788867583** | **pool-001** | **2025-11-07** | **BROKEN (0.0 quotas)** |
| 831494785845 | pool-002 | 2025-11-28 | Working |
| 340601547583 | pool-003 | 2025-12-04 | Working |
| 982203978489 | pool-004 | 2025-12-04 | Working |
| 680464296760 | pool-005 | 2025-12-23 | Working |
| 404584456509 | pool-006 | 2025-12-23 | Working |
| 417845783913 | pool-007 | 2025-12-23 | Working |
| 221792773038 | pool-008 | 2025-12-23 | Working |
| 848960887562 | pool-009 | 2026-01-15 | Working |

**This rules out "new account restrictions" as the cause.**

---

## Investigation Findings

### 1. CloudTrail Evidence

All recent `InvokeModel` calls to Nova Pro are failing:

```
errorCode: "ThrottlingException"
errorMessage: "Too many tokens per day, please wait before trying again."
modelId: "amazon.nova-pro-v1:0"
```

Events recorded on Jan 16 and Jan 19, 2026 - **100% failure rate**.

### 2. Current Quota Values (pool-001)

| Metric | Value |
|--------|-------|
| On-demand tokens/min (Nova Pro) | **0.0** |
| On-demand requests/min (Nova Pro) | **0.0** |
| Max tokens/day (Nova Pro) | **0.0** |
| Same for Nova Lite, Nova Micro | **0.0** |

For comparison, management account (955063685555) has 1,000,000 tokens/min.

### 3. What We Ruled Out

#### SCPs Are NOT Blocking Bedrock

The `InnovationSandboxAwsNukeSupportedServicesScp` explicitly **allows** Bedrock:
```hcl
# Line 82 of modules/scp-manager/main.tf
"bedrock:*"  # In the allowlist
```

No SCP in our Terraform code denies Bedrock API calls.

#### "New Account" Theory is WRONG

Initially hypothesized that AWS restricts Bedrock on new accounts. However:
- pool-001 is the **oldest** pool account
- Newer accounts (pool-002 through pool-009) **work fine**
- This is clearly an account-specific issue, not a systemic one

#### Service Quota Templates Are NOT Setting Zero Values

Checked management account - **no Bedrock templates are defined**:
```
=== Bedrock Service Quota Templates ===
ServiceQuotaIncreaseRequestInTemplateList: []
```

#### The Removed service-quotas-manager Module Never Had Bedrock

The module removed in PR #17 only managed: EC2, EBS, Lambda, VPC, RDS, EKS.
**Bedrock quotas were never managed by our Terraform.**

### 4. Possible Causes for Pool-001 Specifically

| Possibility | Likelihood | Details |
|-------------|------------|---------|
| **AWS Trust & Safety flag** | High | Pool-001 may have triggered fraud/abuse detection |
| **Excessive historical usage** | Medium | If pool-001 was heavily used, AWS may have reduced quotas |
| **Billing/Payment issue** | Low | Could be flagged for billing reasons |
| **Manual AWS intervention** | Possible | AWS Support may have reduced quotas after an incident |
| **Model access revocation** | Possible | Bedrock model access may have been revoked |

---

## Why This Cannot Be Fixed With Terraform

1. **Quotas are non-adjustable**: The `Adjustable: false` flag means the Service Quotas API rejects programmatic changes
2. **Templates won't work**: Service Quota Templates can only set values for adjustable quotas
3. **AWS requires manual review**: Support ticket required to investigate and restore quotas

### AWS Confirmation (22 Jan 2026)

Joe Reay (AWS) confirmed:
> "Can confirm it isn't possible to reduce service quotas. Isaac (GDS TAM) is probably the best person to explore other potential options with."

A call is being scheduled with the ISB team to discuss alternatives.

---

## SCP Options for Bedrock Cost Control

Since quotas cannot be reduced programmatically, here are SCP-based alternatives to control Bedrock costs:

### Option 1: Block Expensive Bedrock Models

Allow cheap models (Nova Micro/Lite) but deny expensive ones (Claude, Llama 405B, Titan Premier):

```hcl
{
  "Sid": "DenyExpensiveBedrockModels",
  "Effect": "Deny",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream"
  ],
  "Resource": [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-*",
    "arn:aws:bedrock:*::foundation-model/meta.llama3-1-405b*",
    "arn:aws:bedrock:*::foundation-model/amazon.titan-text-premier*",
    "arn:aws:bedrock:*::foundation-model/ai21.*",
    "arn:aws:bedrock:*::foundation-model/cohere.*"
  ],
  "Condition": {
    "ArnNotLike": {
      "aws:PrincipalARN": ["arn:aws:iam::*:role/InnovationSandbox-*"]
    }
  }
}
```

**Pros:** Users can still use Bedrock with cheaper models (Nova family)
**Cons:** Blocks legitimate use cases requiring advanced models

### Option 2: Block Model Access Enablement

Prevent users from enabling additional Bedrock models beyond what's pre-configured:

```hcl
{
  "Sid": "DenyBedrockModelEntitlement",
  "Effect": "Deny",
  "Action": [
    "bedrock:PutFoundationModelEntitlement",
    "bedrock:CreateModelCustomizationJob",
    "bedrock:CreateProvisionedModelThroughput"
  ],
  "Resource": "*",
  "Condition": {
    "ArnNotLike": {
      "aws:PrincipalARN": ["arn:aws:iam::*:role/InnovationSandbox-*"]
    }
  }
}
```

**Pros:** Prevents enabling expensive models; blocks provisioned throughput (very expensive)
**Cons:** Requires pre-enabling desired models in each account

### Option 3: AWS Budgets with Auto-Actions

Set up budget alerts that trigger Lambda to revoke Bedrock permissions when threshold exceeded:

1. Create AWS Budget for Bedrock service ($X/day threshold)
2. Budget action triggers SNS → Lambda
3. Lambda attaches deny SCP to the specific account
4. Manual review required to restore access

**Pros:** Dynamic, responds to actual spend
**Cons:** Complex to implement; reactive not preventive

### Option 4: Block Bedrock Entirely (Nuclear Option)

Remove `bedrock:*` from the `nuke_supported_services` allowlist in `scp-manager/main.tf`:

```hcl
# Remove this line from local.nuke_supported_services:
# "bedrock:*",
```

**Pros:** Zero Bedrock costs
**Cons:** Blocks all AI/ML experimentation - defeats purpose of sandbox

### Questions for Isaac (GDS TAM)

1. Can AWS apply account-level spending caps for Bedrock specifically?
2. Are there AWS-side controls for token limits per account?
3. What happened to pool-001 specifically - can AWS investigate?
4. Is there a Private Marketplace or other mechanism to control model access org-wide?
5. Can Bedrock Guardrails be used for cost control (not just content)?

---

## Recommended Actions

### Immediate: Investigate Pool-001 Specifically

1. **Submit AWS Support ticket** for account 449788867583 (pool-001):
   - Subject: "Bedrock quotas showing 0.0 - please investigate account status"
   - Include: Account is part of Innovation Sandbox; was working previously; other accounts work fine
   - Ask: Is there a Trust & Safety flag? Was quota manually reduced? Model access status?

2. **Check Bedrock Model Access** in pool-001:
   ```bash
   aws bedrock list-foundation-models --region us-east-1 \
     --query 'modelSummaries[?contains(modelId, `nova`)]'
   ```
   - If models don't appear, model access may have been revoked

3. **Compare with working account** (e.g., pool-002):
   - Verify quotas are healthy in newer accounts
   - Confirm the issue is isolated to pool-001

### Short-term: Consider Rotating Pool-001

If AWS cannot restore quotas quickly:
- Remove pool-001 from the active pool
- Replace with a new account
- Keep pool-001 for investigation/testing

### Long-term: Monitoring

Add monitoring to detect quota issues before they impact users:
- Alert when Bedrock ThrottlingExceptions occur
- Periodic quota checks across pool accounts

---

## Additional Finding: SCP Blocks Service Quotas API

The `InnovationSandboxAwsNukeSupportedServicesScp` uses a `NotAction` allowlist that does NOT include `servicequotas:*`. This means:

- Users cannot query their own quotas from sandbox accounts
- This is intentional (service quotas isn't in AWS Nuke scope)
- Quota monitoring must be done from the management account

---

## References

- [AWS Bedrock Quotas Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/quotas.html)
- [Request Bedrock Quota Increase](https://docs.aws.amazon.com/bedrock/latest/userguide/quotas-increase.html)
- PR #17: Removed service-quotas-manager module (confirmed Bedrock was never managed)

---

## Appendix: Commands Used for Investigation

```bash
# Check CloudTrail for Bedrock errors (from management account)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=InvokeModel \
  --region us-east-1

# Check current quotas (from management account, targeting sandbox)
aws service-quotas list-service-quotas --service-code bedrock --region us-east-1

# Check Service Quota Templates (management account only)
aws service-quotas list-service-quota-increase-requests-in-template \
  --service-code bedrock --region us-east-1

# Verify model is accessible (not blocked by SCP)
aws bedrock list-foundation-models --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `nova-pro`)]'

# List all pool accounts (from management account)
aws organizations list-accounts-for-parent \
  --parent-id ou-xxxx-xxxxxxxx \
  --query 'Accounts[*].[Id,Name,JoinedTimestamp]' --output table

# Compare quotas between accounts (requires assuming role in each)
# Note: servicequotas:* is blocked by SCP in sandbox accounts
# Must query from management account using Organizations APIs
```

---

## Appendix: Pool Account Timeline

| Account | Name | Created | Notes |
|---------|------|---------|-------|
| 449788867583 | pool-001 | 2025-11-07 | **BROKEN** - Bedrock quotas 0.0 |
| 831494785845 | pool-002 | 2025-11-28 | Working |
| 340601547583 | pool-003 | 2025-12-04 | Working |
| 982203978489 | pool-004 | 2025-12-04 | Working |
| 680464296760 | pool-005 | 2025-12-23 | Working |
| 404584456509 | pool-006 | 2025-12-23 | Working |
| 417845783913 | pool-007 | 2025-12-23 | Working |
| 221792773038 | pool-008 | 2025-12-23 | Working |
| 848960887562 | pool-009 | 2026-01-15 | Working |
