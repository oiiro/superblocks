# --- outputs.tf ---
# Output values for Aurora MySQL and Bastion module

# Aurora Cluster Outputs
output "aurora_cluster_id" {
  description = "The RDS Cluster Identifier"
  value       = aws_rds_cluster.aurora_mysql.cluster_identifier
}

output "aurora_writer_endpoint" {
  description = "Writer endpoint for the Aurora cluster"
  value       = aws_rds_cluster.aurora_mysql.endpoint
}

output "aurora_reader_endpoint" {
  description = "Reader endpoint for the Aurora cluster"
  value       = aws_rds_cluster.aurora_mysql.reader_endpoint
}

output "aurora_port" {
  description = "The database port"
  value       = aws_rds_cluster.aurora_mysql.port
}

output "aurora_database_name" {
  description = "Name of the default database"
  value       = aws_rds_cluster.aurora_mysql.database_name
}

# Secrets Manager Output
output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_secret_name" {
  description = "Name of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}

# Security Group Outputs
output "aurora_security_group_id" {
  description = "Security group ID for Aurora cluster"
  value       = aws_security_group.aurora.id
}

output "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  value       = var.enable_bastion ? aws_security_group.bastion[0].id : null
}

# Bastion Outputs
output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

output "bastion_private_ip" {
  description = "Private IP address of the bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].private_ip : null
}

# Connection Information
output "connection_info" {
  description = "Database connection information and commands"
  value = {
    jdbc_writer_url = "jdbc:mysql://${aws_rds_cluster.aurora_mysql.endpoint}:${aws_rds_cluster.aurora_mysql.port}/${aws_rds_cluster.aurora_mysql.database_name}"
    jdbc_reader_url = "jdbc:mysql://${aws_rds_cluster.aurora_mysql.reader_endpoint}:${aws_rds_cluster.aurora_mysql.port}/${aws_rds_cluster.aurora_mysql.database_name}"

    mysql_writer_url = "mysql://${var.db_master_username}:PASSWORD@${aws_rds_cluster.aurora_mysql.endpoint}:${aws_rds_cluster.aurora_mysql.port}/${aws_rds_cluster.aurora_mysql.database_name}"
    mysql_reader_url = "mysql://${var.db_master_username}:PASSWORD@${aws_rds_cluster.aurora_mysql.reader_endpoint}:${aws_rds_cluster.aurora_mysql.port}/${aws_rds_cluster.aurora_mysql.database_name}"

    ssm_tunnel_command = var.enable_bastion ? "aws ssm start-session --target ${aws_instance.bastion[0].id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters 'host=\"${aws_rds_cluster.aurora_mysql.endpoint}\",portNumber=\"3306\",localPortNumber=\"3306\"'" : "Bastion not enabled"

    ssm_connect_command = var.enable_bastion ? "aws ssm start-session --target ${aws_instance.bastion[0].id}" : "Bastion not enabled"
  }
}

# Developer Guide Output
output "developer_guide" {
  description = "Complete developer guide for database access"
  value       = <<-EOT
    ========================================
    AURORA MYSQL DATABASE ACCESS GUIDE
    ========================================

    DATABASE ENDPOINTS:
    -------------------
    Writer: ${aws_rds_cluster.aurora_mysql.endpoint}:${aws_rds_cluster.aurora_mysql.port}
    Reader: ${aws_rds_cluster.aurora_mysql.reader_endpoint}:${aws_rds_cluster.aurora_mysql.port}
    Database: ${aws_rds_cluster.aurora_mysql.database_name}

    CREDENTIALS:
    ------------
    Secret ARN: ${aws_secretsmanager_secret.db_credentials.arn}
    Secret Name: ${aws_secretsmanager_secret.db_credentials.name}

    To retrieve credentials:
    aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_credentials.name} --query SecretString --output text | jq .

    CONNECTION OPTIONS:
    -------------------

    1. SSM PORT FORWARDING (Recommended):
    ${var.enable_bastion ? "   aws ssm start-session --target ${aws_instance.bastion[0].id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters 'host=\"${aws_rds_cluster.aurora_mysql.endpoint}\",portNumber=\"3306\",localPortNumber=\"3306\"'" : "   Bastion not enabled"}

       Then connect locally:
       mysql -h 127.0.0.1 -P 3306 -u ${var.db_master_username} -p ${aws_rds_cluster.aurora_mysql.database_name}

    2. SSM SESSION TO BASTION:
    ${var.enable_bastion ? "   aws ssm start-session --target ${aws_instance.bastion[0].id}" : "   Bastion not enabled"}

       Once connected, use:
       /usr/local/bin/connect-aurora.sh

    3. JDBC CONNECTION STRINGS:
       Writer: jdbc:mysql://${aws_rds_cluster.aurora_mysql.endpoint}:${aws_rds_cluster.aurora_mysql.port}/${aws_rds_cluster.aurora_mysql.database_name}
       Reader: jdbc:mysql://${aws_rds_cluster.aurora_mysql.reader_endpoint}:${aws_rds_cluster.aurora_mysql.port}/${aws_rds_cluster.aurora_mysql.database_name}

    4. APPLICATION CONNECTION:
       Host: ${aws_rds_cluster.aurora_mysql.endpoint}
       Port: ${aws_rds_cluster.aurora_mysql.port}
       Database: ${aws_rds_cluster.aurora_mysql.database_name}
       SSL: Enabled (recommended)

    APPLYING DDL:
    -------------
    1. Connect using method above
    2. Run: mysql -h 127.0.0.1 -P 3306 -u ${var.db_master_username} -p ${aws_rds_cluster.aurora_mysql.database_name} < sql/001_init_schema.sql

    MONITORING:
    -----------
    CloudWatch Logs: ${local.name_prefix}-aurora
    Performance Insights: ${var.performance_insights_enabled ? "Enabled" : "Disabled"}
    Enhanced Monitoring: ${var.enhanced_monitoring_interval > 0 ? "Enabled (${var.enhanced_monitoring_interval}s)" : "Disabled"}

    SECURITY:
    ---------
    - Database is in private subnets
    - Not publicly accessible
    - Encrypted at rest
    - SSL/TLS enforced
    ${var.enable_bastion ? "- Bastion access via SSM (no SSH required)" : "- No bastion deployed"}

    ========================================
  EOT
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of deployed configuration"
  value = {
    cluster_mode        = local.is_serverless ? "Serverless v2" : "Provisioned"
    serverless_acus     = local.is_serverless ? "${var.serverless_min_acu} - ${var.serverless_max_acu}" : "N/A"
    instance_class      = local.is_serverless ? "db.serverless" : var.provisioned_instance_class
    instance_count      = length(aws_rds_cluster_instance.aurora)
    backup_retention    = var.backup_retention_period
    deletion_protection = var.deletion_protection
    bastion_enabled     = var.enable_bastion
    environment         = var.env
  }
}