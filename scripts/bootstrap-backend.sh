#!/bin/bash
# Bootstrap script to create S3 backend for Terraform state
# Run this ONCE before initializing Terraform
#
# Creates:
#   - S3 bucket for state storage (versioned, encrypted)
#   - DynamoDB table for state locking

set -e

# Configuration
ACCOUNT_ID="955063685555"
REGION="eu-west-2"
BUCKET_NAME="ndx-terraform-state-${ACCOUNT_ID}"
DYNAMODB_TABLE="ndx-terraform-locks"

echo "=== NDX Terraform Backend Bootstrap ==="
echo ""
echo "This script will create:"
echo "  - S3 Bucket: ${BUCKET_NAME}"
echo "  - DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  - Region: ${REGION}"
echo ""

# Check AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS CLI not configured or no valid credentials"
    exit 1
fi

# Verify account
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
if [ "$CURRENT_ACCOUNT" != "$ACCOUNT_ID" ]; then
    echo "ERROR: Expected account ${ACCOUNT_ID}, got ${CURRENT_ACCOUNT}"
    echo "Make sure you're using credentials for gds-ndx-try-aws-org-management"
    exit 1
fi

echo "AWS Identity:"
aws sts get-caller-identity
echo ""

# Create S3 bucket
echo "Creating S3 bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "  Bucket already exists"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    echo "  Created bucket: ${BUCKET_NAME}"
fi

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'

# Add bucket policy to enforce encryption in transit
echo "Adding bucket policy..."
aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Sid\": \"EnforceTLS\",
                \"Effect\": \"Deny\",
                \"Principal\": \"*\",
                \"Action\": \"s3:*\",
                \"Resource\": [
                    \"arn:aws:s3:::${BUCKET_NAME}\",
                    \"arn:aws:s3:::${BUCKET_NAME}/*\"
                ],
                \"Condition\": {
                    \"Bool\": {
                        \"aws:SecureTransport\": \"false\"
                    }
                }
            }
        ]
    }"

# Create DynamoDB table for locking
echo "Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &>/dev/null; then
    echo "  Table already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
    echo "  Created table: ${DYNAMODB_TABLE}"

    # Wait for table to be active
    echo "  Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
fi

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Backend configuration:"
echo "  bucket         = \"${BUCKET_NAME}\""
echo "  key            = \"scp-overrides/terraform.tfstate\""
echo "  region         = \"${REGION}\""
echo "  encrypt        = true"
echo "  dynamodb_table = \"${DYNAMODB_TABLE}\""
echo ""
echo "Next steps:"
echo "  cd ../environments/ndx-production"
echo "  terraform init"
echo "  ./../../scripts/import-existing-scps.sh"
