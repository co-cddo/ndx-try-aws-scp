#!/bin/bash
# Script to import existing ISB SCPs into Terraform state
# Run this ONCE before applying Terraform changes
#
# SCP Policy IDs (from AWS Console 2026-01-09):
#   InnovationSandboxAwsNukeSupportedServicesScp: p-7pd0szg9
#   InnovationSandboxLimitRegionsScp: p-02s3te0u
#   InnovationSandboxProtectISBResourcesScp: p-gn4fu3co
#   InnovationSandboxRestrictionsScp: p-6tw8eixp
#   InnovationSandboxWriteProtectionScp: p-tyb1wjxv

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/../environments/ndx-production"

# Known Policy IDs from AWS Console
NUKE_SCP_ID="p-7pd0szg9"
REGIONS_SCP_ID="p-02s3te0u"

echo "=== NDX SCP Import Script ==="
echo ""
echo "This script will import existing Innovation Sandbox SCPs into Terraform state."
echo ""
echo "Policy IDs to import:"
echo "  - NukeSupportedServices: ${NUKE_SCP_ID}"
echo "  - LimitRegions: ${REGIONS_SCP_ID}"
echo ""

# Check AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS CLI not configured or no valid credentials"
    echo "Make sure you're logged into the management account (955063685555)"
    exit 1
fi

echo "AWS Identity:"
aws sts get-caller-identity
echo ""

# Verify we're in the right account
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
if [ "$ACCOUNT_ID" != "955063685555" ]; then
    echo "WARNING: Expected management account 955063685555, got ${ACCOUNT_ID}"
    echo "Make sure you're using credentials for gds-ndx-try-aws-org-management"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "=== Initializing Terraform ==="
cd "$ENV_DIR"
terraform init

echo ""
echo "=== Importing SCPs ==="
echo ""

# Import NukeSupportedServices SCP
echo "Importing NukeSupportedServices SCP (${NUKE_SCP_ID})..."
terraform import \
    module.scp_manager.aws_organizations_policy.nuke_supported_services \
    "$NUKE_SCP_ID" 2>/dev/null || echo "  Already imported or import failed"

# Import LimitRegions SCP
echo "Importing LimitRegions SCP (${REGIONS_SCP_ID})..."
terraform import \
    module.scp_manager.aws_organizations_policy.limit_regions \
    "$REGIONS_SCP_ID" 2>/dev/null || echo "  Already imported or import failed"

echo ""
echo "=== Import Complete ==="
echo ""
echo "Next steps:"
echo "  1. Review the plan: terraform plan"
echo "  2. Apply changes: terraform apply"
echo ""
echo "NOTE: The Cost Avoidance SCP is NEW and will be created (not imported)"
echo ""
echo "IMPORTANT: After applying, the ISB CDK will show drift on these SCPs."
echo "Do NOT re-deploy the ISB Account Pool stack without re-applying Terraform."
