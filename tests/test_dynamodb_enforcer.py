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


class TestExtractEventMetadata:
    """Tests for extract_event_metadata function."""

    def test_extracts_account_id_from_recipient(self, mock_env):
        """Should extract account ID from recipientAccountId."""
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert metadata['account_id'] == '123456789012'

    def test_extracts_region(self, mock_env):
        """Should extract AWS region."""
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert metadata['region'] == 'us-west-2'

    def test_extracts_user_arn(self, mock_env):
        """Should extract user ARN from userIdentity."""
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert 'TestRole' in metadata['user_arn']

    def test_extracts_source_ip(self, mock_env):
        """Should extract source IP address."""
        from index import extract_event_metadata

        metadata = extract_event_metadata(SAMPLE_CLOUDTRAIL_EVENT)

        assert metadata['source_ip'] == '192.168.1.1'

    def test_handles_missing_fields(self, mock_env):
        """Should handle missing fields gracefully."""
        from index import extract_event_metadata

        minimal_event = {'detail': {}}
        metadata = extract_event_metadata(minimal_event)

        assert metadata['account_id'] == 'unknown'
        assert metadata['region'] == 'unknown'


class TestLambdaHandler:
    """Tests for lambda_handler function."""

    def test_returns_early_if_no_table_name(self, mock_env):
        """Should return early if no table name in event."""
        import index

        event = {'detail': {'requestParameters': {}}}
        result = index.lambda_handler(event, None)

        assert result['statusCode'] == 200
        assert 'No table name' in result['body']

    def test_skips_exempt_table_prefixes(self, mock_env):
        """Should skip tables matching exempt prefixes."""
        import index

        # Reload to pick up env vars
        index.EXEMPT_TABLE_PREFIXES = ['terraform-', 'infrastructure-']

        event = SAMPLE_CLOUDTRAIL_EVENT.copy()
        event['detail'] = SAMPLE_CLOUDTRAIL_EVENT['detail'].copy()
        event['detail']['requestParameters'] = {'tableName': 'terraform-state-lock'}

        result = index.lambda_handler(event, None)

        assert result['statusCode'] == 200
        assert 'exempt' in result['body']

    def test_handles_table_not_found(self, mock_env):
        """Should handle ResourceNotFoundException gracefully."""
        import index

        # Create a proper exception class
        class ResourceNotFoundException(Exception):
            pass

        # Mock the dynamodb client
        mock_dynamodb = MagicMock()
        mock_dynamodb.exceptions.ResourceNotFoundException = ResourceNotFoundException
        mock_dynamodb.describe_table.side_effect = ResourceNotFoundException("Table not found")

        with patch.object(index, 'dynamodb', mock_dynamodb):
            result = index.lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert result['statusCode'] == 200
        assert 'not found' in result['body']

    def test_allows_provisioned_tables(self, mock_env):
        """Should allow tables with PROVISIONED billing mode."""
        import index

        mock_dynamodb = MagicMock()
        mock_dynamodb.describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PROVISIONED'}
            }
        }

        with patch.object(index, 'dynamodb', mock_dynamodb):
            result = index.lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert result['statusCode'] == 200
        assert 'already provisioned' in result['body']
        mock_dynamodb.delete_table.assert_not_called()

    def test_deletes_on_demand_tables(self, mock_env):
        """Should delete tables with PAY_PER_REQUEST billing mode."""
        import index

        mock_dynamodb = MagicMock()
        mock_dynamodb.describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        mock_events = MagicMock()
        mock_sns = MagicMock()

        with patch.object(index, 'dynamodb', mock_dynamodb), \
             patch.object(index, 'events', mock_events), \
             patch.object(index, 'sns', mock_sns):
            result = index.lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert result['statusCode'] == 200
        assert 'DELETED' in result['body']
        mock_dynamodb.delete_table.assert_called_once_with(TableName='test-table')

    def test_broadcasts_eventbridge_event(self, mock_env):
        """Should broadcast event to EventBridge with account ID."""
        import index

        mock_dynamodb = MagicMock()
        mock_dynamodb.describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        mock_events = MagicMock()
        mock_sns = MagicMock()

        with patch.object(index, 'dynamodb', mock_dynamodb), \
             patch.object(index, 'events', mock_events), \
             patch.object(index, 'sns', mock_sns):
            index.lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        mock_events.put_events.assert_called_once()
        call_args = mock_events.put_events.call_args
        event_detail = json.loads(call_args[1]['Entries'][0]['Detail'])

        assert event_detail['accountId'] == '123456789012'
        assert event_detail['region'] == 'us-west-2'
        assert event_detail['tableName'] == 'test-table'
        assert event_detail['action'] == 'DELETED'
        assert 'triggeredBy' in event_detail

    def test_sends_sns_notification(self, mock_env):
        """Should send SNS notification with MessageAttributes."""
        import index

        # Set the SNS topic ARN
        index.SNS_TOPIC_ARN = 'arn:aws:sns:us-west-2:123456789012:test-topic'

        mock_dynamodb = MagicMock()
        mock_dynamodb.describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        mock_events = MagicMock()
        mock_sns = MagicMock()

        with patch.object(index, 'dynamodb', mock_dynamodb), \
             patch.object(index, 'events', mock_events), \
             patch.object(index, 'sns', mock_sns):
            index.lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        mock_sns.publish.assert_called_once()
        call_args = mock_sns.publish.call_args

        assert 'MessageAttributes' in call_args[1]
        assert call_args[1]['MessageAttributes']['accountId']['StringValue'] == '123456789012'

    def test_includes_account_in_message(self, mock_env):
        """Should include account ID in the notification message."""
        import index

        mock_dynamodb = MagicMock()
        mock_dynamodb.describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        mock_events = MagicMock()
        mock_sns = MagicMock()

        with patch.object(index, 'dynamodb', mock_dynamodb), \
             patch.object(index, 'events', mock_events), \
             patch.object(index, 'sns', mock_sns):
            result = index.lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        assert '123456789012' in result['body']
        assert 'us-west-2' in result['body']


class TestEventBridgeEventSchema:
    """Tests to document the EventBridge event schema."""

    def test_event_schema_documentation(self, mock_env):
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
        import index

        mock_dynamodb = MagicMock()
        mock_dynamodb.describe_table.return_value = {
            'Table': {
                'TableName': 'test-table',
                'BillingModeSummary': {'BillingMode': 'PAY_PER_REQUEST'}
            }
        }

        mock_events = MagicMock()
        mock_sns = MagicMock()

        # Set the event source
        index.EVENTBRIDGE_SOURCE = 'ndx.dynamodb-billing-enforcer'

        with patch.object(index, 'dynamodb', mock_dynamodb), \
             patch.object(index, 'events', mock_events), \
             patch.object(index, 'sns', mock_sns):
            index.lambda_handler(SAMPLE_CLOUDTRAIL_EVENT, None)

        call_args = mock_events.put_events.call_args
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
