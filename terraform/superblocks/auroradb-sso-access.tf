# --- auroradb-sso-access.tf ---
# Grant AWS SSO users and vendor IAM users access to Aurora database credentials
# This allows users to retrieve database credentials from Secrets Manager

# Get current AWS account ID
data "aws_caller_identity" "aurora_current" {}

# Get current region
data "aws_region" "aurora_current" {}

# ===== SSO ROLE NAMES =====
# INSTRUCTIONS: Run this command to find your SSO roles:
#   aws iam list-roles --query 'Roles[?contains(RoleName, `AWSReservedSSO`)].RoleName' --output text
#
# Then add them to the list below:

locals {
  # Add your SSO role names here
  aurora_sso_roles_with_access = [
    # "AWSReservedSSO_AWSAdministratorAccess_abc123def456",  # Example - replace with actual role name
    # "AWSReservedSSO_DeveloperAccess_xyz789ghi012",         # Example - add more roles as needed
  ]

  # Add vendor/external IAM user names here
  # INSTRUCTIONS: Run this command to find IAM users:
  #   aws iam list-users --query 'Users[].UserName' --output table
  aurora_vendor_users_with_access = [
    # "vendor-api-user",      # Example - replace with actual vendor user name
    # "external-service",     # Example - add more vendor users as needed
  ]
}

# ===== IAM POLICY FOR AURORA ACCESS =====

# Policy to access Aurora database credentials in Secrets Manager
resource "aws_iam_policy" "aurora_secrets_access" {
  name        = "superblocks-aurora-secrets-access"
  description = "Allows SSO users and vendors to access Aurora database credentials via Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerReadAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          module.database.db_secret_arn
        ]
      },
      {
        Sid    = "SecretsManagerListSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSDescribeAccess"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusterEndpoints"
        ]
        Resource = [
          "arn:aws:rds:${data.aws_region.aurora_current.name}:${data.aws_caller_identity.aurora_current.account_id}:cluster:superblocks-dev-aurora*",
          "arn:aws:rds:${data.aws_region.aurora_current.name}:${data.aws_caller_identity.aurora_current.account_id}:db:superblocks-dev-aurora*"
        ]
      },
      {
        Sid    = "SSMBastionAccess"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ec2:${data.aws_region.aurora_current.name}:${data.aws_caller_identity.aurora_current.account_id}:instance/*"
        ]
        Condition = {
          StringLike = {
            "ssm:resourceTag/Name" = "superblocks-dev-bastion"
          }
        }
      },
      {
        Sid    = "SSMSessionDocuments"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.aurora_current.name}::document/AWS-StartSSHSession",
          "arn:aws:ssm:${data.aws_region.aurora_current.name}::document/AWS-StartPortForwardingSession",
          "arn:aws:ssm:${data.aws_region.aurora_current.name}::document/AWS-StartPortForwardingSessionToRemoteHost"
        ]
      },
      {
        Sid    = "SSMSessionControl"
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "superblocks-aurora-secrets-access"
    Application = "superblocks"
    ManagedBy   = "terraform"
    Purpose     = "Aurora database access for SSO users and vendors"
  }
}

# ===== ATTACH POLICY TO SSO ROLES =====

# Attach the policy to each SSO role
resource "aws_iam_role_policy_attachment" "aurora_sso_access" {
  for_each = toset(local.aurora_sso_roles_with_access)

  role       = each.value
  policy_arn = aws_iam_policy.aurora_secrets_access.arn
}

# ===== ATTACH POLICY TO VENDOR IAM USERS =====

# Attach the policy to each vendor IAM user
resource "aws_iam_user_policy_attachment" "aurora_vendor_access" {
  for_each = toset(local.aurora_vendor_users_with_access)

  user       = each.value
  policy_arn = aws_iam_policy.aurora_secrets_access.arn
}

# ===== OUTPUTS =====

output "aurora_secrets_policy_arn" {
  description = "ARN of the IAM policy granting Aurora secrets access"
  value       = aws_iam_policy.aurora_secrets_access.arn
}

output "aurora_sso_roles_with_access" {
  description = "List of SSO roles that have Aurora database access"
  value       = local.aurora_sso_roles_with_access
}

output "aurora_vendor_users_with_access" {
  description = "List of vendor IAM users that have Aurora database access"
  value       = local.aurora_vendor_users_with_access
}

output "aurora_access_instructions" {
  description = "Instructions for accessing Aurora database"
  value       = <<-EOT
    ========================================
    AURORA DATABASE ACCESS INSTRUCTIONS
    ========================================

    SSO USERS / VENDOR USERS CAN NOW:
    -----------------------------------

    1. RETRIEVE DATABASE CREDENTIALS:
       aws secretsmanager get-secret-value \
         --secret-id ${module.database.db_secret_name} \
         --query SecretString --output text | jq .

    2. DESCRIBE AURORA CLUSTER:
       aws rds describe-db-clusters \
         --db-cluster-identifier superblocks-dev-aurora

    3. CONNECT VIA SSM PORT FORWARDING:
       # Start port forwarding session
       ${module.database.connection_info.ssm_tunnel_command}

       # Then connect from local machine
       mysql -h 127.0.0.1 -P 3306 -u wegdbadmin -p wegdemodb

    4. CONNECT VIA SSM TO BASTION:
       ${module.database.connection_info.ssm_connect_command}

       # Once on bastion, use the helper script
       /usr/local/bin/connect-aurora.sh

    ========================================
    WHAT ACCESS WAS GRANTED:
    ========================================

    ✓ Read Aurora database credentials from Secrets Manager
    ✓ Describe Aurora cluster and instances
    ✓ Start SSM sessions to bastion host
    ✓ Create port forwarding tunnels to database

    ========================================
    SECURITY NOTES:
    ========================================

    - Database is NOT publicly accessible
    - Access only via bastion host or port forwarding
    - Credentials stored in AWS Secrets Manager
    - All connections require valid AWS credentials
    - SSM sessions are logged in CloudWatch

    ========================================
  EOT
}
