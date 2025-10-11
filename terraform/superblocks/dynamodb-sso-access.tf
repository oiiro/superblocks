# --- dynamodb-sso-access.tf ---
# Grant AWS SSO users and vendor IAM users access to all DynamoDB tables
# This file manages IAM policies for SSO role and vendor user access to DynamoDB

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ===== SSO ROLE NAMES =====
# INSTRUCTIONS: Run this command to find your SSO roles:
#   aws iam list-roles --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].RoleName' --output text
#
# Then add them to the list below:

locals {
  # Add your SSO role names here
  sso_roles_with_dynamodb_access = [
    # "AWSReservedSSO_AWSAdministratorAccess_abc123def456",  # Example - replace with actual role name
    # "AWSReservedSSO_PowerUserAccess_xyz789ghi012",         # Example - add more roles as needed
    # "AWSReservedSSO_DeveloperAccess_mno345pqr678",         # Example
  ]

  # Add vendor/external IAM user names here
  # INSTRUCTIONS: Run this command to find IAM users:
  #   aws iam list-users --query 'Users[].UserName' --output table
  vendor_users_with_dynamodb_access = [
    # "vendor-api-user",      # Example - replace with actual vendor user name
    # "external-service",     # Example - add more vendor users as needed
    # "third-party-user",     # Example
  ]
}

# ===== IAM POLICY FOR DYNAMODB ACCESS =====

# Create a policy that grants access to all superblocksdemo DynamoDB tables
resource "aws_iam_policy" "sso_dynamodb_access" {
  name        = "superblocksdemo-sso-dynamodb-access"
  description = "Allows SSO users to access all superblocksdemo DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/superblocksdemo-*",
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/superblocksdemo-*/index/*"
        ]
      },
      {
        Sid    = "DynamoDBListTables"
        Effect = "Allow"
        Action = [
          "dynamodb:ListTables",
          "dynamodb:DescribeLimits"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "superblocksdemo-sso-dynamodb-access"
    Application = "superblocksdemo"
    ManagedBy   = "terraform"
    Purpose     = "SSO user access to DynamoDB"
  }
}

# ===== ATTACH POLICY TO SSO ROLES =====

# Attach the policy to each SSO role
resource "aws_iam_role_policy_attachment" "sso_dynamodb_access" {
  for_each = toset(local.sso_roles_with_dynamodb_access)

  role       = each.value
  policy_arn = aws_iam_policy.sso_dynamodb_access.arn
}

# ===== ATTACH POLICY TO VENDOR IAM USERS =====

# Attach the policy to each vendor IAM user
resource "aws_iam_user_policy_attachment" "vendor_dynamodb_access" {
  for_each = toset(local.vendor_users_with_dynamodb_access)

  user       = each.value
  policy_arn = aws_iam_policy.sso_dynamodb_access.arn
}

# ===== OUTPUTS =====

output "sso_dynamodb_policy_arn" {
  description = "ARN of the IAM policy granting SSO users DynamoDB access"
  value       = aws_iam_policy.sso_dynamodb_access.arn
}

output "sso_roles_with_dynamodb_access" {
  description = "List of SSO roles that have DynamoDB access"
  value       = local.sso_roles_with_dynamodb_access
}

output "vendor_users_with_dynamodb_access" {
  description = "List of vendor IAM users that have DynamoDB access"
  value       = local.vendor_users_with_dynamodb_access
}
