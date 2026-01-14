# SCP Consolidation Analysis

## Current State

AWS limit: **5 SCPs per OU**

### SCPs Created by This Module

| SCP Name | Attached To | Conditional | Lines |
|----------|-------------|-------------|-------|
| `InnovationSandboxAwsNukeSupportedServicesScp` | sandbox_ou_id | No | ~200 |
| `InnovationSandboxLimitRegionsScp` | sandbox_ou_id | No | ~25 |
| `InnovationSandboxCostAvoidanceScp` | cost_avoidance_ou_id (Active) | No | ~280 |
| `InnovationSandboxIamWorkloadIdentityScp` | sandbox_ou_id | Yes (disabled by default) | ~130 |
| `InnovationSandboxRestrictionsScp` | (imported, not attached) | No | ~130 |

### OU Structure

```
Sandbox Pool OU (ou-2laj-4dyae1oa) ← sandbox_ou_id
├── SCPs: NukeSupportedServices, LimitRegions, [IamWorkloadIdentity]
│
└── Active OU (ou-2laj-sre4rnjs) ← cost_avoidance_ou_id
    ├── SCPs: CostAvoidance
    │
    └── Pool Accounts (pool-001, pool-002, etc.)
```

**Note:** SCPs on parent OU apply to all children. So Active OU accounts get both their own SCPs plus parent SCPs.

## Consolidation Options

### Option 1: Merge LimitRegions into CostAvoidance (Recommended)

**Pros:**
- Region limits are fundamentally a cost control (prevent expensive regions)
- Reduces sandbox_ou_id SCPs from 2 to 1
- Logical grouping of all cost-related controls

**Cons:**
- CostAvoidance is on Active OU, not parent
- Would need to move combined SCP to parent for region limits to apply to Pool accounts

**Implementation:**
```hcl
# Add to cost_avoidance Statement array:
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
    }
  }
}
```

### Option 2: Keep IAM Workload Identity Disabled

**Current state:** `enable_iam_workload_identity = false`

With IAM SCP disabled, we have:
- sandbox_ou_id: 2 SCPs (Nuke, LimitRegions)
- Active OU: 1 SCP (CostAvoidance)

This leaves buffer room without any changes.

### Option 3: Consolidate Security SCPs

Merge `IamWorkloadIdentityScp` statements into `RestrictionsScp`.

**Pros:**
- Both are IAM/security related
- Single security policy

**Cons:**
- Restrictions has `prevent_destroy = true`
- Imported SCP, more risk to modify

## Recommendation

1. **Short-term:** Keep `enable_iam_workload_identity = false` (current)
   - This keeps us at 2 SCPs on sandbox_ou_id
   - Leaves room for 3 more before hitting limit

2. **Medium-term:** If IAM workload identity is needed:
   - Merge LimitRegions into CostAvoidance
   - Move combined SCP to sandbox_ou_id
   - This would give: Nuke + CostAvoidance + IamWorkloadIdentity = 3 SCPs

3. **Before changes:** Audit ISB's existing SCPs
   ```bash
   aws organizations list-policies-for-target \
     --target-id ou-2laj-4dyae1oa \
     --filter SERVICE_CONTROL_POLICY
   ```

## SCP Size Limits

AWS also has a 5,120 character limit per SCP. Current sizes:
- NukeSupportedServices: ~4,500 chars (close to limit!)
- CostAvoidance: ~3,800 chars
- LimitRegions: ~600 chars
- IamWorkloadIdentity: ~2,500 chars

Merging should consider character limits. NukeSupportedServices cannot grow much more.
