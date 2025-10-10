# --- outputs.tf ---
# Output values for DynamoDB table module

output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.this.arn
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy granting DynamoDB access"
  value       = aws_iam_policy.dynamodb_access.arn
}

output "attached_roles" {
  description = "List of IAM roles with DynamoDB access"
  value = concat(
    [var.ecs_task_role_name],
    var.additional_role_names
  )
}
