"""
DynamoDB Billing Mode Enforcer Lambda

Enforces DynamoDB billing mode policy by DELETING On-Demand tables.
Triggered by EventBridge when CreateTable or UpdateTable is called.

This prevents cost overruns since On-Demand mode bypasses WCU/RCU service quotas.
"""
import json
import os

import boto3

dynamodb = boto3.client('dynamodb')
sns = boto3.client('sns')
events = boto3.client('events')

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
EXEMPT_TABLE_PREFIXES = os.environ.get('EXEMPT_TABLE_PREFIXES', '').split(',')
EVENT_BUS_NAME = os.environ.get('EVENT_BUS_NAME', 'default')
EVENTBRIDGE_SOURCE = os.environ.get('EVENTBRIDGE_SOURCE', 'sandbox.dynamodb-billing-enforcer')


def lambda_handler(event, context):
    """
    Enforces DynamoDB billing mode policy by DELETING On-Demand tables.
    Triggered by EventBridge when CreateTable or UpdateTable is called.
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        detail = event.get('detail', {})
        event_name = detail.get('eventName', '')

        # Extract table name from the API call
        request_params = detail.get('requestParameters', {})
        table_name = request_params.get('tableName', '')

        if not table_name:
            print("No table name found in event")
            return {'statusCode': 200, 'body': 'No table name'}

        # Check if table is exempt
        for prefix in EXEMPT_TABLE_PREFIXES:
            if prefix and table_name.startswith(prefix.strip()):
                print(f"Table {table_name} is exempt (prefix: {prefix})")
                return {'statusCode': 200, 'body': f'Table {table_name} exempt'}

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
            message = f"DynamoDB table '{table_name}' detected with On-Demand billing mode."

            try:
                dynamodb.delete_table(TableName=table_name)
                message += " TABLE DELETED."
                print(message)

                # Broadcast to EventBridge
                events.put_events(
                    Entries=[
                        {
                            'Source': EVENTBRIDGE_SOURCE,
                            'DetailType': 'DynamoDB On-Demand Table Deleted',
                            'Detail': json.dumps({
                                'tableName': table_name,
                                'action': 'DELETED',
                                'reason': 'On-Demand billing mode not allowed'
                            }),
                            'EventBusName': EVENT_BUS_NAME
                        }
                    ]
                )
                print(f"EventBridge event broadcast for table {table_name}")

            except Exception as e:
                message += f" FAILED to delete: {str(e)}"
                print(message)

            # Send SNS notification
            if SNS_TOPIC_ARN:
                try:
                    sns.publish(
                        TopicArn=SNS_TOPIC_ARN,
                        Subject=f"[COST ALERT] DynamoDB On-Demand Table Deleted: {table_name}",
                        Message=message
                    )
                except Exception as e:
                    print(f"Failed to send SNS notification: {str(e)}")

            return {'statusCode': 200, 'body': message}

        return {'statusCode': 200, 'body': f'Table {table_name} is already provisioned'}

    except Exception as e:
        print(f"Error processing event: {str(e)}")
        raise
