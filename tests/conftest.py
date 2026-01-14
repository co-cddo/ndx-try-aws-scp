"""
Pytest configuration and fixtures for Lambda tests.

This file sets up the AWS environment before any test modules are imported.
"""
import os
import sys

# Set AWS region BEFORE any boto3 imports happen
# This must be done at conftest.py level to run before test collection
os.environ['AWS_DEFAULT_REGION'] = 'us-west-2'
os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
os.environ['AWS_SECURITY_TOKEN'] = 'testing'
os.environ['AWS_SESSION_TOKEN'] = 'testing'

# Add lambda directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'modules', 'dynamodb-billing-enforcer', 'lambda'))
