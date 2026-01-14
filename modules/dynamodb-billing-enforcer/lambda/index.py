"""
DynamoDB Billing Mode Enforcer Lambda

Enforces DynamoDB billing mode policy by DELETING On-Demand tables.
Triggered by EventBridge when CreateTable or UpdateTable is called.

This prevents cost overruns since On-Demand mode bypasses WCU/RCU service quotas.

DEPLOYMENT:
    This Lambda is deployed to the ISB Hub/Management account.
    It monitors DynamoDB events via CloudTrail and EventBridge.

    For cross-account monitoring, sandbox accounts must forward CloudTrail
    events to the Hub account's EventBridge bus.

SNS/EVENTBRIDGE:
    - SNS Topic: Created in Hub account by budgets-manager module
    - EventBridge: Uses default event bus in Hub account
    - Cross-account: Sandbox events forwarded via EventBridge rules

EVENT FLOW:
    1. User creates DynamoDB table in Sandbox Account
    2. CloudTrail logs the CreateTable API call
    3. EventBridge rule (in sandbox) forwards to Hub account event bus
    4. This Lambda is triggered
    5. Lambda deletes the table (cross-account via IAM role)
    6. Lambda broadcasts event and sends SNS notification
"""
import json
import os
from datetime import datetime, timezone


def get_config():
    """Get configuration from environment variables."""
    return {
        'sns_topic_arn': os.environ.get('SNS_TOPIC_ARN', ''),
        'exempt_table_prefixes': os.environ.get('EXEMPT_TABLE_PREFIXES', '').split(','),
        'event_bus_name': os.environ.get('EVENT_BUS_NAME', 'default'),
        'eventbridge_source': os.environ.get('EVENTBRIDGE_SOURCE', 'sandbox.dynamodb-billing-enforcer'),
    }


def get_boto3_client(service_name):
    """
    Create boto3 client lazily.

    This allows Lambda container reuse while making the code testable.
    Clients are cached by boto3 internally when running in Lambda.
    """
    import boto3
    return boto3.client(service_name)


def extract_event_metadata(event: dict) -> dict:
    """
    Extract metadata from CloudTrail event for logging and notifications.

    Args:
        event: The CloudTrail event received via EventBridge

    Returns:
        Dictionary with extracted metadata
    """
    detail = event.get('detail', {})
    user_identity = detail.get('userIdentity', {})

    return {
        'account_id': detail.get('recipientAccountId', event.get('account', 'unknown')),
        'region': detail.get('awsRegion', event.get('region', 'unknown')),
        'event_time': detail.get('eventTime', datetime.now(timezone.utc).isoformat()),
        'event_name': detail.get('eventName', 'unknown'),
        'user_type': user_identity.get('type', 'unknown'),
        'user_arn': user_identity.get('arn', 'unknown'),
        'user_principal': user_identity.get('principalId', 'unknown'),
        'source_ip': detail.get('sourceIPAddress', 'unknown'),
        'user_agent': detail.get('userAgent', 'unknown'),
    }


def lambda_handler(event, context):
    """
    Enforces DynamoDB billing mode policy by DELETING On-Demand tables.
    Triggered by EventBridge when CreateTable or UpdateTable is called.

    Args:
        event: CloudTrail event from EventBridge containing DynamoDB API call details
        context: Lambda context object

    Returns:
        dict with statusCode and body describing the action taken
    """
    print(f"Received event: {json.dumps(event)}")

    # Get configuration
    config = get_config()

    try:
        detail = event.get('detail', {})
        metadata = extract_event_metadata(event)

        # Extract table name from the API call
        request_params = detail.get('requestParameters', {})
        table_name = request_params.get('tableName', '')

        if not table_name:
            print("No table name found in event")
            return {'statusCode': 200, 'body': 'No table name'}

        print(f"Processing table '{table_name}' in account {metadata['account_id']}, "
              f"region {metadata['region']}, triggered by {metadata['user_arn']}")

        # Check if table is exempt
        for prefix in config['exempt_table_prefixes']:
            if prefix and table_name.startswith(prefix.strip()):
                print(f"Table {table_name} is exempt (prefix: {prefix})")
                return {'statusCode': 200, 'body': f'Table {table_name} exempt'}

        # Get DynamoDB client
        dynamodb = get_boto3_client('dynamodb')

        # Get current table status
        try:
            response = dynamodb.describe_table(TableName=table_name)
            table = response['Table']
            billing_mode = table.get('BillingModeSummary', {}).get('BillingMode', 'PROVISIONED')
        except dynamodb.exceptions.ResourceNotFoundException:
            print(f"Table {table_name} not found (may have been deleted)")
            return {'statusCode': 200, 'body': 'Table not found'}

        print(f"Table {table_name} has billing mode: {billing_mode}")

        # If table is On-Demand, DELETE it
        if billing_mode == 'PAY_PER_REQUEST':
            message = (
                f"DynamoDB table '{table_name}' detected with On-Demand billing mode.\n"
                f"Account: {metadata['account_id']}\n"
                f"Region: {metadata['region']}\n"
                f"Created by: {metadata['user_arn']}\n"
                f"Source IP: {metadata['source_ip']}"
            )

            delete_success = False
            try:
                dynamodb.delete_table(TableName=table_name)
                message += "\n\nACTION: TABLE DELETED."
                delete_success = True
                print(message)

            except Exception as e:
                message += f"\n\nACTION FAILED: {str(e)}"
                print(message)

            # Broadcast to EventBridge with full metadata
            event_detail = {
                'tableName': table_name,
                'action': 'DELETED' if delete_success else 'DELETE_FAILED',
                'reason': 'On-Demand billing mode not allowed',
                'accountId': metadata['account_id'],
                'region': metadata['region'],
                'eventTime': metadata['event_time'],
                'triggeredBy': {
                    'userArn': metadata['user_arn'],
                    'userType': metadata['user_type'],
                    'principalId': metadata['user_principal'],
                    'sourceIp': metadata['source_ip'],
                },
                'enforcementTimestamp': datetime.now(timezone.utc).isoformat(),
            }

            try:
                events_client = get_boto3_client('events')
                events_client.put_events(
                    Entries=[
                        {
                            'Source': config['eventbridge_source'],
                            'DetailType': 'DynamoDB On-Demand Table Deleted',
                            'Detail': json.dumps(event_detail),
                            'EventBusName': config['event_bus_name']
                        }
                    ]
                )
                print(f"EventBridge event broadcast: {json.dumps(event_detail)}")
            except Exception as e:
                print(f"Failed to broadcast EventBridge event: {str(e)}")

            # Send SNS notification
            if config['sns_topic_arn']:
                try:
                    sns_client = get_boto3_client('sns')
                    sns_client.publish(
                        TopicArn=config['sns_topic_arn'],
                        Subject=f"[COST ALERT] DynamoDB On-Demand Table Deleted: {table_name}",
                        Message=message,
                        MessageAttributes={
                            'accountId': {
                                'DataType': 'String',
                                'StringValue': metadata['account_id']
                            },
                            'region': {
                                'DataType': 'String',
                                'StringValue': metadata['region']
                            },
                            'tableName': {
                                'DataType': 'String',
                                'StringValue': table_name
                            },
                            'action': {
                                'DataType': 'String',
                                'StringValue': 'DELETED' if delete_success else 'DELETE_FAILED'
                            }
                        }
                    )
                    print("SNS notification sent")
                except Exception as e:
                    print(f"Failed to send SNS notification: {str(e)}")

            return {'statusCode': 200, 'body': message}

        return {'statusCode': 200, 'body': f'Table {table_name} is already provisioned'}

    except Exception as e:
        print(f"Error processing event: {str(e)}")
        raise
