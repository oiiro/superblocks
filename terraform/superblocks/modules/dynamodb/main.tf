# --- main.tf ---
# DynamoDB table with ECS task IAM access
# Configuration: Pay-per-request, AWS managed encryption, no backup

locals {
  # Determine if range key is used
  has_range_key = var.range_key != ""
}

# ===== DYNAMODB TABLE =====

resource "aws_dynamodb_table" "this" {
  name         = "${var.app_name}-${var.table_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.hash_key
  range_key    = local.has_range_key ? var.range_key : null

  # Hash key attribute
  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Range key attribute (if specified)
  dynamic "attribute" {
    for_each = local.has_range_key ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  # No point-in-time recovery (no backup)
  point_in_time_recovery {
    enabled = false
  }

  # AWS managed encryption (default)
  server_side_encryption {
    enabled = true
    # kms_key_arn not specified = AWS managed key
  }

  # No deletion protection for development
  deletion_protection_enabled = false

  tags = {
    Name        = "${var.app_name}-${var.table_name}"
    Project     = var.app_name
    ManagedBy   = "terraform"
    Application = "superblocksdemo"
  }
}

# ===== IAM POLICY FOR ECS TASK ROLE =====

# IAM policy document for full DynamoDB table access
data "aws_iam_policy_document" "dynamodb_access" {
  statement {
    sid    = "DynamoDBTableAccess"
    effect = "Allow"

    actions = [
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

    resources = [
      aws_dynamodb_table.this.arn,
      "${aws_dynamodb_table.this.arn}/index/*"
    ]
  }
}

# IAM policy resource
resource "aws_iam_policy" "dynamodb_access" {
  name_prefix = "${var.app_name}-${var.table_name}-"
  description = "Allows ECS task to access DynamoDB table ${var.table_name}"
  policy      = data.aws_iam_policy_document.dynamodb_access.json

  tags = {
    Name        = "${var.app_name}-${var.table_name}-policy"
    Project     = var.app_name
    ManagedBy   = "terraform"
    Application = "superblocksdemo"
  }
}

# Attach policy to ECS task role
resource "aws_iam_role_policy_attachment" "dynamodb_access_ecs" {
  role       = var.ecs_task_role_name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# Attach policy to additional roles (bastion, lambda, etc.)
resource "aws_iam_role_policy_attachment" "dynamodb_access_additional" {
  for_each = toset(var.additional_role_names)

  role       = each.value
  policy_arn = aws_iam_policy.dynamodb_access.arn
}
