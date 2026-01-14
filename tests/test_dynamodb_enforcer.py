"""
Unit tests for DynamoDB Billing Mode Enforcer Lambda

Run with: pytest tests/ -v
"""
import json
import os
import sys
from unittest.mock import MagicMock, patch

import pytest

# Add lambda directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'modules', 'dynamodb-billing-enforcer', 'lambda'))


# Sample CloudTrail event for DynamoDB CreateTable
SAMPLE_CLOUDTRAIL_EVENT = {
    'version': '0',
    'id': 'test-event-id',
    'detail-type': 'AWS API Call via CloudTrail',
    'source': 'aws.dynamodb',
    'account': '123456789012',
    'time': '2025-01-14T12:00:00Z',
    'region': 'us-west-2',
    'detail': {
        'eventVersion': '1.08',
        'userIdentity': {
            'type': 'AssumedRole',
            'principalId': 'AROAEXAMPLEID:user@example.com',
            'arn': 'arn:aws:sts::123456789012:assumed-role/TestRole/user@example.com',
            'accountId': '123456789012',
        },
        'eventTime': '2025-01-14T12:00:00Z',
        'eventSource': 'dynamodb.amazonaws.com',
        'eventName': 'CreateTable',
        'awsRegion': 'us-west-2',
        'sourceIPAddress': '192.168.1.1',
        'userAgent': 'aws-cli/2.0',
        'requestParameters': {
            'tableName': 'test-table',
            'billingMode': 'PAY_PER_REQUEST',
        },
        'recipientAccountId': '123456789012',
    }
}


@pytest.fixture
def mock_env():
    """Set up environment variables for Lambda."""
    with patch.dict(os.environ, {
        'SNS_TOPIC_ARN': 'arn:aws:sns:us-west-2:123456789012:test-topic',
        'EXEMPT_TABLE_PREFIXES': 'terraform-,infrastructure-',
        'EVENT_BUS_NAME': 'default',
        'EVENTBRIDGE_SOURCE': 'ndx.dynamodb-billing-enforcer',
    }):
        yield


@pytest.fixture
def mock_boto3_clients():
    """Mock all boto3 clients."""
    with patch('boto3.client') as mock_client:
        # Create mock clients
        mock_dynamodb = MagicMock()
        mock_sns = MagicMock()
        mock_events = MagicMock()
        mock_sts = MagicMock()

        def client_factory(service_name, **kwargs):
            clients = {
                'dynamodb': mock_dynamodb,
                'sns': mock_sns,
                'events': mock_events,
                'sts': mock_sts,
            }
            return clients.get(service_name, MagicMock())

        mock_client.side_effect = client_factory

        yield {
            'dynamodb': mock_dynamodb,
            'sns': mock_sns,
            'events': mock_events,
            'sts': mock_sts,
        }


class TestExtractEventMetadata:
    """Tests for extract_event_metadata function."""

    def test_extracts_account_id_from_recipient(self, mock_env, mock_boto3_clients):
        """Should extract account ID from recipientAccountId."""
        # Import after mocking
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert metadata['account_id'] == '123456789012'

    def test_extracts_region(self, mock_env, mock_boto3_clients):
        """Should extract AWS region."""
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert metadata['region'] == 'us-west-2'

    def test_extracts_user_arn(self, mock_env, mock_boto3_clients):
        """Should extract user ARN from userIdentity."""
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert 'TestRole' in metadata['user_arn']

    def test_extracts_source_ip(self, mock_env, mock_boto3_clients):
        """Should extract source IP address."""
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert metadata['source_ip'] == '192.168.1.1'

    def test_handles_missing_fields(self, mock_env, mock_boto3_clients):
        """Should handle missing fields gracefully."""
        from index import extract_event_metadata

        minimal_event = {'detail': {}}
        metadata = extract_event_metadata(minimal_event)

        assert metadata['account_id'] == 'unknown'
        assert metadata['region'] == 'unknown'


class TestLambdaHandler:
    """Tests for lambda_handler function."""

    def test_returns_early_if_no_table_name(self, mock_env, mock_boto3_clients):
        """Should return early if no table name in event."""
        from index import lambda_handler

        event = {'detail': {'requestParameters': {}}}
        result = lambda_handler(event, None)

        assert result['statusCode'] == 200
        assert 'No table name' in result['body']

    def test_skips_exempt_table_prefixes(self, mock_env, mock_boto3_clients):
        """Should skip tables matching exempt prefixes."""
        from index import lambda_handler

        event = SAMPLE_CLOUDTRAIL_EVENT.copy()
        event['detail'] = SAMPLE_CLOUDTRAIL_EVENT['detail'].copy()
        event['detail']['requestParameters'] = {'tableName': 'terraform-state-lock'}

        result = lambda_handler(event, None)

        assert result['statusCode'] == 200
        assert 'exempt' in result['body']

    def test_handles_table_not_found(self, mock_env, mock_boto3_clients):
        """Should handle ResourceNotFoundException gracefully."""
        from index import lambda_handler

        mock_boto3_clients['dynamodb'].describe_table.side_effect = \
            mock_boto3_clients['dynamodb'].exceptions.ResourceNotFoundException(
                {'Error': {'Code': 'ResourceNotFoundException'}},
                'DescribeTable'
            )

        # Need to set up the exception class
        mock_boto3_clients['dynamodb'].exceptions.ResourceNotFoundException = type(
            'ResourceNotFoundException', (Exception,), {}
        )
        mock_boto3_clients['dynamodb'].describe_table.side_effect = \
            mock_boto3_clients['dynamodb'].exceptions.ResourceNotFoundException()

        result = lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert result['statusCode'] == 200
        assert 'not found' in result['body']

    def test_allows_provisioned_tables(self, mock_env, mock_boto3_clients):
        """Should allow tables with PROVISIONED billing mode."""
        from index import lambda_handler

        mock_boto3_clients['dynamodb'].describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PROVISIONED'}
            }
        }

        result = lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert result['statusCode'] == 200
        assert 'already provisioned' in result['body']
        mock_boto3_clients['dynamodb'].delete_table.assert_not_called()

    def test_deletes_on_demand_tables(self, mock_env, mock_boto3_clients):
        """Should delete tables with PAY_PER_REQUEST billing mode."""
        from index import lambda_handler

        mock_boto3_clients['dynamodb'].describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        result = lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert result['statusCode'] == 200
        assert 'DELETED' in result['body']
        mock_boto3_clients['dynamodb'].delete_table.assert_called_once_with(
            TableName='test-table'
        )

    def test_broadcasts_eventbridge_event(self, mock_env, mock_boto3_clients):
        """Should broadcast event to EventBridge with account ID."""
        from index import lambda_handler

        mock_boto3_clients['dynamodb'].describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        mock_boto3_clients['events'].put_events.assert_called_once()
        call_args = mock_boto3_clients['events'].put_events.call_args
        event_detail = json.loads(call_args[1]['Entries'][0]['Detail'])

        assert event_detail['accountId'] == '123456789012'
        assert event_detail['region'] == 'us-west-2'
        assert event_detail['tableName'] == 'test-table'
        assert event_detail['action'] == 'DELETED'
        assert 'triggeredBy' in event_detail

    def test_sends_sns_notification(self, mock_env, mock_boto3_clients):
        """Should send SNS notification with MessageAttributes."""
        from index import lambda_handler

        mock_boto3_clients['dynamodb'].describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        mock_boto3_clients['sns'].publish.assert_called_once()
        call_args = mock_boto3_clients['sns'].publish.call_args

        assert 'MessageAttributes' in call_args[1]
        assert call_args[1]['MessageAttributes']['accountId']['StringValue'] == '123456789012'

    def test_includes_account_in_message(self, mock_env, mock_boto3_clients):
        """Should include account ID in the notification message."""
        from index import lambda_handler

        mock_boto3_clients['dynamodb'].describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        result = lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert '123456789012' in result['body']
        assert 'us-west-2' in result['body']


class TestEventBridgeEventSchema:
    """Tests to document the EventBridge event schema."""

    def test_event_schema_documentation(self, mock_env, mock_boto3_clients):
        """
        Documents the EventBridge event schema for notification systems.

        The event published to EventBridge has this structure:
        {
            "Source": "ndx.dynamodb-billing-enforcer",
            "DetailType": "DynamoDB On-Demand Table Deleted",
            "Detail": {
                "tableName": "string",
                "action": "DELETED" | "DELETE_FAILED",
                "reason": "On-Demand billing mode not allowed",
                "accountId": "123456789012",
                "region": "us-west-2",
                "eventTime": "2025-01-14T12:00:00Z",
                "triggeredBy": {
                    "userArn": "arn:aws:sts::123456789012:assumed-role/...",
                    "userType": "AssumedRole",
                    "principalId": "AROAEXAMPLEID:user@example.com",
                    "sourceIp": "192.168.1.1"
                },
                "enforcementTimestamp": "2025-01-14T12:00:01Z"
            }
        }

        To subscribe to these events in another system, create an EventBridge rule:
        {
            "source": ["ndx.dynamodb-billing-enforcer"],
            "detail-type": ["DynamoDB On-Demand Table Deleted"]
        }
        """
        from index import lambda_handler

        mock_boto3_clients['dynamodb'].describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        call_args = mock_boto3_clients['events'].put_events.call_args
        event_entry = call_args[1]['Entries'][0]
        event_detail = json.loads(event_entry['Detail'])

        # Verify schema
        assert event_entry['Source'] == 'ndx.dynamodb-billing-enforcer'
        assert event_entry['DetailType'] == 'DynamoDB On-Demand Table Deleted'

        # Required fields
        required_fields = ['tableName', 'action', 'reason', 'accountId', 'region',
                          'eventTime', 'triggeredBy', 'enforcementTimestamp']
        for field in required_fields:
            assert field in event_detail, f"Missing required field: {field}"

        # triggeredBy nested fields
        triggered_by_fields = ['userArn', 'userType', 'principalId', 'sourceIp']
        for field in triggered_by_fields:
            assert field in event_detail['triggeredBy'], f"Missing triggeredBy field: {field}"
