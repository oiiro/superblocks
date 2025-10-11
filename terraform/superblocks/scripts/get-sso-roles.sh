#!/bin/bash
# --- get-sso-roles.sh ---
# Helper script to find AWS SSO roles for DynamoDB access configuration

set -e

echo "========================================="
echo "Finding AWS SSO Roles"
echo "========================================="
echo ""

# Get current identity
echo "Current AWS Identity:"
aws sts get-caller-identity
echo ""

# Get all SSO roles
echo "All SSO Roles in this account:"
echo "========================================="
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].{RoleName:RoleName,Description:Description,CreateDate:CreateDate}' \
  --output table

echo ""
echo "========================================="
echo "SSO Role Names (copy these to dynamodb-sso-access.tf):"
echo "========================================="
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].RoleName' \
  --output text | tr '\t' '\n' | while read role; do
  echo "    \"$role\","
done

echo ""
echo "========================================="
echo "Instructions:"
echo "========================================="
echo "1. Copy the role names above"
echo "2. Edit terraform/superblocks/dynamodb-sso-access.tf"
echo "3. Add the role names to the 'sso_roles_with_dynamodb_access' list"
echo "4. Run: terraform plan"
echo "5. Run: terraform apply"
echo ""
