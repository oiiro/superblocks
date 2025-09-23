# Outputs for Superblocks Agent Module

output "agent_url" {
  description = "URL to access the Superblocks agent"
  value       = var.enable_ssl ? "https://${aws_lb.superblocks.dns_name}" : "http://${aws_lb.superblocks.dns_name}"
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.superblocks.dns_name
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.superblocks.arn
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer (for Route53 Alias records)"
  value       = aws_lb.superblocks.zone_id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.superblocks.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.superblocks.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.superblocks.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.superblocks.id
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.superblocks.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = var.vpc_id
}

output "lb_security_group_id" {
  description = "Load balancer security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs.id
}

output "certificate_arn" {
  description = "ARN of the SSL certificate (if SSL enabled)"
  value       = var.enable_ssl ? (var.certificate_arn != "" ? var.certificate_arn : aws_acm_certificate.superblocks[0].arn) : null
}

output "certificate_warning" {
  description = "SSL certificate warning (if using self-signed)"
  value       = var.enable_ssl && var.certificate_arn == "" ? "WARNING: Using self-signed certificate. You will see SSL warnings in your browser." : null
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.superblocks.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.superblocks.arn
}

output "container_environment_variables" {
  description = "All environment variables configured in the ECS task definition (showing final values after overrides)"
  value = merge(
    # Built-in module environment variables
    {
      "SUPERBLOCKS_AGENT_HOST_URL" = var.domain != "" && var.subdomain != "" ? "${local.protocol}://${var.subdomain}.${var.domain}" : "${local.protocol}://${aws_lb.superblocks.dns_name}"
      "SUPERBLOCKS_AGENT_ENVIRONMENT" = var.superblocks_agent_environment
      "SUPERBLOCKS_AGENT_TAGS" = var.superblocks_agent_tags
      "SUPERBLOCKS_SERVER_URL" = "https://api.superblocks.com"
      "SUPERBLOCKS_AGENT_DATA_DOMAIN" = "app.superblocks.com"
      "SUPERBLOCKS_WORKER_LOCAL_ENABLED" = "true"
    },
    # Agent key (from direct variable or secrets manager)
    local.use_secrets_manager ? {
      "SUPERBLOCKS_AGENT_KEY" = "[FROM_SECRETS_MANAGER: ${var.agent_key_secret_arn}]"
    } : {
      "SUPERBLOCKS_AGENT_KEY" = "[SENSITIVE_VALUE]"
    },
    # User-defined environment variables (these OVERRIDE built-in ones)
    var.environment_variables
  )
}

output "environment_variable_precedence" {
  description = "Shows which variables are overridden by user-defined environment_variables"
  value = {
    built_in_variables = [
      "SUPERBLOCKS_AGENT_HOST_URL",
      "SUPERBLOCKS_AGENT_ENVIRONMENT",
      "SUPERBLOCKS_AGENT_TAGS",
      "SUPERBLOCKS_SERVER_URL",
      "SUPERBLOCKS_AGENT_DATA_DOMAIN",
      "SUPERBLOCKS_WORKER_LOCAL_ENABLED",
      "SUPERBLOCKS_AGENT_KEY"
    ]
    user_override_variables = keys(var.environment_variables)
    overridden_built_ins = [
      for var_name in keys(var.environment_variables) : var_name
      if contains([
        "SUPERBLOCKS_AGENT_HOST_URL",
        "SUPERBLOCKS_AGENT_ENVIRONMENT",
        "SUPERBLOCKS_AGENT_TAGS",
        "SUPERBLOCKS_SERVER_URL",
        "SUPERBLOCKS_AGENT_DATA_DOMAIN",
        "SUPERBLOCKS_WORKER_LOCAL_ENABLED",
        "SUPERBLOCKS_AGENT_KEY"
      ], var_name)
    ]
  }
}