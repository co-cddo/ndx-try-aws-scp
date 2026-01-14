"""
Pytest configuration and fixtures for Lambda tests.

This file sets up the test environment before any test modules are imported.
No AWS credentials needed - Lambda uses lazy client initialization, fully mockable.
"""
import os
import sys

# Add lambda directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'modules', 'dynamodb-billing-enforcer', 'lambda'))
