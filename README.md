# NDX Innovation Sandbox - Cost Defense System

Comprehensive Terraform modules for cost control in the NDX Innovation Sandbox AWS deployment. Implements **3-layer defense-in-depth** architecture to protect against cost attacks in 24-hour sandbox leases.

## Table of Contents

- [Defense Architecture](#defense-architecture)
- [Quick Start](#quick-start)
- [Modules](#modules)
  - [scp-manager](#1-scp-manager)
  - [budgets-manager](#2-budgets-manager)
  - [dynamodb-billing-enforcer](#3-dynamodb-billing-enforcer)
- [Cost Protection Analysis](#cost-protection-analysis)
- [Attack Vector Coverage](#attack-vector-coverage)
- [Configuration](#configuration)
- [Deployment](#deployment)

---

## Defense Architecture

Each sandbox lease is **24 hours**. The 3-layer defense system prevents runaway costs:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         COST DEFENSE IN DEPTH (3 LAYERS)                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  LAYER 1: SERVICE CONTROL POLICIES (SCPs)                    [PREVENTION]      │
│  ═══════════════════════════════════════════════════════════════════════       │
│  Module: scp-manager                                                            │
│  Controls WHAT actions are allowed                                              │
│  • EC2 instance type allowlist (t2, t3, t3a, m5, m6i - small to xlarge)        │
│  • GPU/accelerated instances BLOCKED (p2-p5, g3-g6, inf1-2, trn1-2)            │
│  • EBS: io1/io2 BLOCKED, max volume 500GB                                      │
│  • RDS: Instance class limits, Multi-AZ BLOCKED, IOPS BLOCKED                  │
│  • 20+ expensive services BLOCKED (SageMaker, EMR, Redshift, MSK, etc.)        │
│  • ASG max size: 10, EKS nodegroup max: 5                                      │
│                                                                                 │
│  LAYER 2: AWS BUDGETS                                        [DETECTION]       │
│  ═══════════════════════════════════════════════════════════════════════       │
│  Module: budgets-manager                                                        │
│  Controls HOW MUCH MONEY can be spent (with aggressive alerting)               │
│  • Daily budget: $50/day (alerts at 10%, 50%, 100%)                            │
│  • Monthly budget: $1000/month                                                 │
│  • 10 service-specific budgets with <1 hour detection:                         │
│    - CloudWatch: $5/day (critical - no service quota for log ingestion)        │
│    - Lambda: $10/day                                                           │
│    - DynamoDB: $5/day                                                          │
│    - Bedrock: $10/day                                                          │
│    - EC2, RDS, S3, API Gateway, Step Functions, Data Transfer                  │
│  • SNS notifications + optional automated actions                              │
│                                                                                 │
│  LAYER 3: DYNAMODB BILLING ENFORCER                          [AUTO-REMEDIATE]  │
│  ═══════════════════════════════════════════════════════════════════════       │
│  Module: dynamodb-billing-enforcer                                              │
│  EventBridge + Lambda to close critical DynamoDB On-Demand gap                 │
│  • Detects CreateTable/UpdateTable with On-Demand billing                      │
│  • Auto-converts to Provisioned mode with enforced capacity limits             │
│  • Max 100 RCU, 100 WCU per table (~$1.87/day vs UNLIMITED)                    │
│  • SNS alerts on enforcement actions                                           │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

```bash
cd environments/ndx-production
terraform init
terraform plan
terraform apply
```

---

## Modules

### 1. scp-manager

**Purpose:** Creates and manages Service Control Policies (SCPs) that PREVENT expensive actions at the AWS API level.

**Location:** `modules/scp-manager/`

**Key Features:**
- **EC2 Controls:** Allowlist of permitted instance types, explicit deny for GPU/accelerated
- **EBS Controls:** Block io1/io2 volumes, limit volume size to 500GB
- **RDS Controls:** Instance class restrictions, Multi-AZ blocked, read replicas blocked
- **ElastiCache Controls:** Node type restrictions
- **Lambda Controls:** Provisioned concurrency blocked
- **EKS/ASG Controls:** Nodegroup and Auto Scaling Group size limits
- **Expensive Services Blocked:** 20+ services including SageMaker, EMR, Redshift, MSK, FSx, etc.

**SCPs Created:**
| SCP Name | Purpose | Conditional |
|----------|---------|-------------|
| `InnovationSandboxAwsNukeSupportedServicesScp` | Allowlist of services (uses NotAction deny) | No |
| `InnovationSandboxRestrictionsScp` | Region restrictions and security isolation | No |
| `InnovationSandboxCostAvoidanceScp` | Comprehensive cost controls | No |
| `InnovationSandboxIamWorkloadIdentityScp` | IAM role/user creation with privilege escalation guardrails | Yes (`enable_iam_workload_identity`, disabled by default) |

**IAM Workload Identity SCP:**

When enabled, sandbox users can create IAM roles and users for their workloads (e.g. EC2 instance profiles, Lambda execution roles) while being prevented from escalating their own privileges.

Users **CAN**:
- Create IAM roles and users for workloads
- Attach policies to their created roles/users
- Create instance profiles for EC2

Users **CANNOT**:
- Create roles/users matching protected name patterns (`Admin*`, `InnovationSandbox*`, `AWSAccelerator*`, `OrganizationAccountAccessRole`, etc.)
- Modify, delete, or attach policies to privileged admin roles
- Pass or assume privileged roles (Control Tower, LZA, service-linked, admin)

```hcl
variable "enable_iam_workload_identity" {
  default = false  # Enable when sandbox users need to create IAM roles
}
```

> **Note:** The Innovation Sandbox `SecurityAndIsolationRestrictions` SCP must also be
> modified to remove `iam:CreateRole` and `iam:CreateUser` from its deny list for this
> SCP to take effect.

**Key Variables:**
```hcl
variable "allowed_ec2_instance_types" {
  default = ["t2.*", "t3.micro", "t3.small", "t3.medium", "t3.large", ...]
}
variable "max_ebs_volume_size_gb" { default = 500 }
variable "max_autoscaling_group_size" { default = 10 }
variable "max_eks_nodegroup_size" { default = 5 }
```

---

### 2. budgets-manager

**Purpose:** Creates AWS Budgets with AGGRESSIVE thresholds for early detection of cost abuse. Alerts within <1 hour of most attack patterns.

**Location:** `modules/budgets-manager/`

**Key Features:**
- Daily and monthly overall budgets
- 10 service-specific budgets for attack vector coverage
- Multi-threshold alerts (50%, 80%, 100%)
- Optional automated actions (stop EC2 at threshold)
- SNS notifications + direct email subscriptions

**Budget Thresholds (Aggressive):**
| Service | Daily Limit | Alert At (50%) | Time to Detect Max Abuse |
|---------|-------------|----------------|--------------------------|
| CloudWatch | **$5** | $2.50 | ~40 seconds |
| Lambda | **$10** | $5 | ~20 minutes |
| DynamoDB | **$5** | $2.50 | ~46 minutes |
| Bedrock | **$10** | $5 | ~33 minutes |
| EC2 | **$10** | $5 | ~1.5 hours |
| RDS | **$5** | $2.50 | ~3 hours |
| S3 | **$10** | $5 | ~1 hour |
| Step Functions | **$5** | $2.50 | ~1 hour |
| API Gateway | **$5** | $2.50 | ~2 hours |
| Data Transfer | **$10** | $5 | ~1 hour |

**Why So Aggressive?**
> CloudWatch Logs ingestion has NO service quota protection.
> At $225/hour potential abuse, a $5/day budget with 50% threshold
> triggers an alert in ~40 seconds of malicious activity.

---

### 3. dynamodb-billing-enforcer

**Purpose:** Closes the CRITICAL gap where DynamoDB On-Demand mode has no capacity limits.

**Location:** `modules/dynamodb-billing-enforcer/`

**The Problem:**
- DynamoDB On-Demand mode is purely pay-per-request with no capacity limits
- Attacker could create On-Demand tables and generate unlimited costs
- There is NO SCP condition key for `dynamodb:BillingMode`

**The Solution:**
- EventBridge rule detects `CreateTable` and `UpdateTable` API calls via CloudTrail
- Lambda function checks billing mode of the table
- If On-Demand detected, automatically converts to Provisioned with enforced limits
- Sends SNS alert about the enforcement action

**Enforcement Modes:**
| Mode | Action |
|------|--------|
| `convert` | Auto-convert to Provisioned (RECOMMENDED) |
| `delete` | Delete the table (aggressive) |
| `alert` | Alert only, no remediation |

**Enforced Capacity:**
```hcl
max_rcu = 100  # ~$0.31/day per table
max_wcu = 100  # ~$1.56/day per table
# Total: ~$1.87/day per table (vs UNLIMITED in On-Demand)
```

---

## Cost Protection Analysis

### Maximum Daily Cost (With All Defenses Active)

| Service | Protection Layer | Max Daily Cost |
|---------|------------------|----------------|
| EC2 Compute | SCP (instance type limits) | ~$77 |
| EBS Storage | SCP (io1/io2 blocked, 500GB max) | ~$6 |
| RDS | SCP (instance class + Multi-AZ blocked) | ~$22 |
| ElastiCache | SCP (node type limits) | ~$40 |
| Lambda | Budget ($10/day) | ~$10 |
| DynamoDB | Enforcer + Budget | ~$5 |
| Bedrock | Budget ($10/day) | ~$10 |
| CloudWatch | Budget ($5/day, alerts fast) | ~$5+ |
| **Total Bounded** | | **~$175/day** |

### Before vs After Defenses

| Attack Vector | Before | After | Reduction |
|---------------|--------|-------|-----------|
| CloudWatch Log Flood | $21,600/day | Budget alerts in ~40 sec | 99%+ awareness |
| Lambda Memory Abuse | $1,440/day | Budget alert at $10/day | 99%+ awareness |
| DynamoDB On-Demand | UNLIMITED | $1.87/table (auto-convert) | 99%+ |
| GPU Instances | $786+/day | BLOCKED (SCP) | 100% |
| Expensive Services | $1000s/day | BLOCKED (SCP) | 100% |

---

## Attack Vector Coverage

| Attack Vector | Layer 1 (SCP) | Layer 2 (Budget) | Layer 3 (Enforcer) |
|---------------|---------------|------------------|---------------------|
| GPU Instances | ✅ BLOCKED | ✅ $10/day | - |
| Large EC2 | ✅ Type limit | ✅ $10/day | - |
| EBS io1/io2 | ✅ BLOCKED | ✅ via EC2 | - |
| RDS Multi-AZ | ✅ BLOCKED | ✅ $5/day | - |
| Lambda Memory | ❌ No SCP key | ✅ $10/day | - |
| DynamoDB On-Demand | ❌ No SCP key | ✅ $5/day | ✅ AUTO-CONVERT |
| CloudWatch Logs | ❌ No SCP key | ✅ $5/day | - |
| Bedrock Tokens | - | ✅ $10/day | - |
| API Gateway | - | ✅ $5/day | - |
| SageMaker | ✅ BLOCKED | - | - |
| EMR | ✅ BLOCKED | - | - |
| Redshift | ✅ BLOCKED | - | - |

**Legend:**
- ✅ Protected
- ❌ No protection at this layer (covered by other layers)
- `-` Not applicable

---

## Configuration

### Environment Variables

The `environments/ndx-production/` configuration uses these key variables:

```hcl
# Enable/disable modules
variable "enable_budgets" { default = true }
variable "enable_dynamodb_billing_enforcer" { default = true }

# Budget limits (aggressive defaults)
variable "daily_budget_limit" { default = 50 }
variable "monthly_budget_limit" { default = 1000 }

# Alert recipients - set via GitHub Actions secret BUDGET_ALERT_EMAILS
# Do NOT hardcode emails in terraform files
variable "budget_alert_emails" {
  default = [] # Provided via TF_VAR_budget_alert_emails from GitHub secret
}
```

### Customization

Each module has extensive configuration options. Key customization points:

1. **Adjust EC2 instance allowlist** (`scp-manager`):
   ```hcl
   allowed_ec2_instance_types = ["t3.micro", "t3.small", "t3.medium"]
   ```

2. **Adjust budget thresholds** (`budgets-manager`):
   ```hcl
   cloudwatch_daily_limit = 10  # Less aggressive
   ```

3. **DynamoDB enforcement mode** (`dynamodb-billing-enforcer`):
   ```hcl
   enforcement_mode = "alert"  # Just alert, don't auto-convert
   ```

---

## Deployment

### Prerequisites

1. AWS CLI configured with Organizations admin access
2. Terraform >= 1.5
3. Access to the management account

### Deployment Steps

```bash
# 1. Initialize
cd environments/ndx-production
terraform init

# 2. Review changes
terraform plan

# 3. Apply
terraform apply
```

### Import Existing SCPs

If SCPs were created by ISB CDK, import them first:

```bash
# Find SCP IDs
aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[?starts_with(Name, `InnovationSandbox`)].{Name:Name,Id:Id}'

# Import
terraform import 'module.scp_manager.aws_organizations_policy.nuke_supported_services' p-xxxxxxxxx
terraform import 'module.scp_manager.aws_organizations_policy.limit_regions' p-yyyyyyyyy
```

### LZA Conflict Resolution

LZA may revert SCP changes. Disable in `security-config.yaml`:

```yaml
scpRevertChangesConfig:
  enable: false
```

---

## Outputs

After deployment, key outputs include:

```hcl
cost_defense_summary = {
  layer_1_scps = { status = "Always enabled", controls = [...] }
  layer_2_budgets = { service_budgets = "10 services monitored" }
  layer_3_dynamodb_enforcer = { mode = "Auto-convert On-Demand to Provisioned" }
  gap_analysis = {
    critical_gaps_closed = [
      "CloudWatch Logs: Budget alert at $5/day",
      "DynamoDB On-Demand: Auto-convert enforcer",
    ]
    defense_effectiveness = "~95% of attack vectors blocked or bounded"
  }
}
```

---

## Repository Structure

```
terraform-scp-overrides/
├── README.md                              # This file
├── modules/
│   ├── scp-manager/                       # Layer 1: Service Control Policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── budgets-manager/                   # Layer 2: AWS Budgets
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── dynamodb-billing-enforcer/         # Layer 3: Auto-remediation
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    └── ndx-production/                    # Production environment
        ├── main.tf
        ├── variables.tf
        └── terraform.tfvars
```

---

## Security Notes

- **No credentials stored** - Uses OIDC for GitHub Actions
- **SCPs use exempt role patterns** - Admin roles are not blocked
- **Budgets alert, don't block** - Ensure monitoring is active
- **DynamoDB enforcer requires CloudTrail** - Ensure CloudTrail is enabled

---

## License

Internal use only - NDX Innovation Sandbox / UK Government Digital Service
