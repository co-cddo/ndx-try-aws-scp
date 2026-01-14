# EventBridge Events Reference

This document describes the EventBridge events published by the cost control modules.
Use this to build notification systems, alerting, or custom integrations.

## DynamoDB Billing Mode Enforcer

### Event: DynamoDB On-Demand Table Deleted

Published when the enforcer deletes (or fails to delete) an On-Demand DynamoDB table.

**Source:** `ndx.dynamodb-billing-enforcer`
**DetailType:** `DynamoDB On-Demand Table Deleted`
**Event Bus:** `default` (Hub account)

#### Event Schema

```json
{
  "version": "0",
  "id": "unique-event-id",
  "detail-type": "DynamoDB On-Demand Table Deleted",
  "source": "ndx.dynamodb-billing-enforcer",
  "account": "HUB_ACCOUNT_ID",
  "time": "2025-01-14T12:00:00Z",
  "region": "us-west-2",
  "detail": {
    "tableName": "user-created-table",
    "action": "DELETED",
    "reason": "On-Demand billing mode not allowed",
    "accountId": "SANDBOX_ACCOUNT_ID",
    "region": "us-west-2",
    "eventTime": "2025-01-14T11:59:55Z",
    "triggeredBy": {
      "userArn": "arn:aws:sts::123456789012:assumed-role/SandboxUserRole/user@example.com",
      "userType": "AssumedRole",
      "principalId": "AROAEXAMPLEID:user@example.com",
      "sourceIp": "192.168.1.1"
    },
    "enforcementTimestamp": "2025-01-14T12:00:01Z"
  }
}
```

#### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `detail.tableName` | string | Name of the DynamoDB table |
| `detail.action` | string | `DELETED` or `DELETE_FAILED` |
| `detail.reason` | string | Always "On-Demand billing mode not allowed" |
| `detail.accountId` | string | AWS account ID where the table was created |
| `detail.region` | string | AWS region where the table was created |
| `detail.eventTime` | ISO8601 | When the user created the table |
| `detail.triggeredBy.userArn` | string | ARN of the user/role that created the table |
| `detail.triggeredBy.userType` | string | IAM identity type (AssumedRole, IAMUser, etc.) |
| `detail.triggeredBy.principalId` | string | Principal ID of the creator |
| `detail.triggeredBy.sourceIp` | string | IP address of the request |
| `detail.enforcementTimestamp` | ISO8601 | When the enforcement action was taken |

#### EventBridge Rule Pattern

To subscribe to these events in another account or service:

```json
{
  "source": ["ndx.dynamodb-billing-enforcer"],
  "detail-type": ["DynamoDB On-Demand Table Deleted"]
}
```

#### Example: Lambda Target for Email Notifications

```python
def lambda_handler(event, context):
    detail = event['detail']

    subject = f"[Sandbox Alert] DynamoDB Table Deleted in {detail['accountId']}"

    body = f"""
A DynamoDB table was automatically deleted due to policy violation.

Table Name: {detail['tableName']}
Account: {detail['accountId']}
Region: {detail['region']}
Action: {detail['action']}

Created By: {detail['triggeredBy']['userArn']}
Source IP: {detail['triggeredBy']['sourceIp']}
Time: {detail['eventTime']}

Reason: {detail['reason']}

This is an automated security measure to prevent cost overruns.
On-Demand DynamoDB tables bypass provisioned capacity quotas.
"""

    # Send email via SES, SNS, or other service
    send_notification(subject, body, detail['accountId'])
```

---

## SNS Notifications

### Budget Alert Topic

The DynamoDB enforcer also publishes to SNS for immediate email alerts.

**Topic ARN:** Created by `budgets-manager` module
**Subject:** `[COST ALERT] DynamoDB On-Demand Table Deleted: {table_name}`

#### Message Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `accountId` | String | AWS account ID |
| `region` | String | AWS region |
| `tableName` | String | DynamoDB table name |
| `action` | String | `DELETED` or `DELETE_FAILED` |

#### Message Body Format

```
DynamoDB table 'user-table' detected with On-Demand billing mode.
Account: 123456789012
Region: us-west-2
Created by: arn:aws:sts::123456789012:assumed-role/SandboxUserRole/user@example.com
Source IP: 192.168.1.1

ACTION: TABLE DELETED.
```

---

## Cross-Account Event Routing

### Architecture

```
Sandbox Account                    Hub Account
┌─────────────────┐               ┌─────────────────────────────┐
│                 │               │                             │
│ DynamoDB        │               │  EventBridge (default bus)  │
│ CreateTable     │               │         │                   │
│      │          │               │         ▼                   │
│      ▼          │               │  ┌─────────────────────┐   │
│ CloudTrail      │──EventBridge──│─▶│ DynamoDB Enforcer   │   │
│                 │   Forwarding  │  │ Lambda              │   │
│                 │               │  └─────────────────────┘   │
│                 │               │         │                   │
│                 │               │         ▼                   │
│                 │               │  ┌─────────────────────┐   │
│                 │               │  │ SNS Topic           │   │
│                 │               │  │ (Budget Alerts)     │   │
│                 │               │  └─────────────────────┘   │
└─────────────────┘               └─────────────────────────────┘
```

### Setting Up Cross-Account Forwarding

Each sandbox account needs an EventBridge rule to forward DynamoDB events to the Hub:

```hcl
# In sandbox account
resource "aws_cloudwatch_event_rule" "forward_dynamodb_events" {
  name = "forward-dynamodb-to-hub"
  event_pattern = jsonencode({
    source      = ["aws.dynamodb"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["dynamodb.amazonaws.com"]
      eventName   = ["CreateTable", "UpdateTable"]
    }
  })
}

resource "aws_cloudwatch_event_target" "hub_event_bus" {
  rule      = aws_cloudwatch_event_rule.forward_dynamodb_events.name
  target_id = "HubEventBus"
  arn       = "arn:aws:events:us-west-2:HUB_ACCOUNT_ID:event-bus/default"
  role_arn  = aws_iam_role.eventbridge_forwarder.arn
}
```
