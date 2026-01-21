# Bedrock Quota Investigation - Account 449788867583

**Date:** 2026-01-21
**Investigator:** Gerard Jarzebak
**Issue:** Bedrock queries (Nova Pro) being blocked with "Too many tokens per day" error

---

## Executive Summary

Sandbox account `449788867583` has **zero Bedrock quotas** for on-demand model inference, causing all Nova Pro API calls to fail with `ThrottlingException`. This is **not caused by our SCPs or Terraform code** - it's an AWS-enforced limitation on new accounts that requires a manual support ticket to resolve.

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

### 2. Current Quota Values

| Account | On-demand tokens/min (Nova Pro) | Status |
|---------|--------------------------------|--------|
| **449788867583** (Sandbox) | **0.0** | Blocked |
| **955063685555** (Management) | 1,000,000 | Working |

All Nova model quotas in the sandbox account are set to 0:
- `On-demand model inference tokens per minute for Amazon Nova Pro: 0.0`
- `On-demand model inference requests per minute for Amazon Nova Pro: 0.0`
- `Model invocation max tokens per day for Amazon Nova Pro: 0.0`
- Same for Nova Lite, Nova Micro, and other models

### 3. What We Ruled Out

#### SCPs Are NOT Blocking Bedrock

The `InnovationSandboxAwsNukeSupportedServicesScp` explicitly **allows** Bedrock:
```hcl
# Line 82 of modules/scp-manager/main.tf
"bedrock:*"  # In the allowlist
```

No SCP in our Terraform code denies Bedrock API calls.

#### Service Quota Templates Are NOT Setting Zero Values

Checked management account - **no Bedrock templates are defined**:
```
=== Bedrock Service Quota Templates ===
ServiceQuotaIncreaseRequestInTemplateList: []
```

Only EC2, Lambda, and EKS templates exist.

#### The Removed service-quotas-manager Module Never Had Bedrock

The module removed in PR #17 only managed: EC2, EBS, Lambda, VPC, RDS, EKS.
**Bedrock quotas were never managed by our Terraform.**

### 4. Root Cause: AWS New Account Restrictions

**AWS has been reducing Bedrock quotas for newly created accounts since 2024/2025.**

Key findings from AWS documentation and community reports:

| Factor | Details |
|--------|---------|
| **New account defaults** | Often 0-2 RPM, 2,000 tokens/min (vs 200,000+ for older accounts) |
| **Adjustable via API?** | **No** - marked as `Adjustable: false` |
| **Why?** | Fraud prevention, payment history, regional factors, demand management |
| **Resolution** | AWS Support ticket required |
| **Timeline** | ~2 weeks for quota restoration |

This explains the discrepancy:
- Management account (older) → healthy quotas
- Sandbox accounts (newly created for pool) → zero quotas

---

## Why This Cannot Be Fixed With Terraform

1. **Quotas are non-adjustable**: The `Adjustable: false` flag means the Service Quotas API rejects programmatic changes
2. **Templates won't work**: Service Quota Templates can only set values for adjustable quotas
3. **AWS requires manual review**: New accounts must be approved before receiving Bedrock capacity

---

## Recommended Actions

### Immediate Fix (Per Account)

1. **Submit AWS Support ticket** for account 449788867583:
   - Service: Amazon Bedrock
   - Request: Increase on-demand inference quotas for Nova models
   - Suggested values: 100,000+ tokens/min for Nova Pro, Lite, Micro

2. **Expected timeline**: ~2 weeks for approval

### Long-term Solutions for Innovation Sandbox

| Option | Pros | Cons |
|--------|------|------|
| **Pre-warm pool accounts** | Accounts ready when leased | Requires planning; 2-week lead time |
| **Use older accounts** | Higher default quotas | May not have enough accounts |
| **Document limitation** | Sets user expectations | Users can't use Bedrock immediately |
| **Automate support tickets** | Scalable | Still requires manual AWS approval |

### Suggested Process Change

When creating new sandbox pool accounts (`innovation-sandbox-on-aws-utils`):

1. Create account
2. Immediately submit Bedrock quota increase request
3. Wait for approval before marking account as "Available" in pool
4. Or: Add "Bedrock-enabled" flag to account metadata for scenarios that need it

---

## References

- [AWS Bedrock Quotas Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/quotas.html)
- [Request Bedrock Quota Increase](https://docs.aws.amazon.com/bedrock/latest/userguide/quotas-increase.html)
- [Ultra Low Bedrock Rate Limits for New Accounts (DEV Community)](https://dev.to/aws-builders/ultra-low-bedrock-llm-rate-limits-for-new-aws-accounts-time-to-wake-up-your-inactive-aws-accounts-3no0)
- [Amazon Bedrock Quota Cuts Explained](https://tobiasto.cloud/post/aws-bedrock-quota-increase/)
- PR #17: Removed service-quotas-manager module (confirmed Bedrock was never managed)

---

## Appendix: Commands Used for Investigation

```bash
# Check CloudTrail for Bedrock errors
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=InvokeModel \
  --region us-east-1

# Check current quotas
aws service-quotas list-service-quotas --service-code bedrock --region us-east-1

# Check Service Quota Templates (management account only)
aws service-quotas list-service-quota-increase-requests-in-template \
  --service-code bedrock --region us-east-1

# Verify model is accessible (not blocked by SCP)
aws bedrock list-foundation-models --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `nova-pro`)]'
```
