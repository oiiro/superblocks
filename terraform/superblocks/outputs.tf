# Outputs for Superblocks Deployment

# Superblocks Module Outputs
output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.superblocks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.superblocks.cluster_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.superblocks.service_name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.superblocks.service_arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.superblocks.task_definition_arn
}

# Load Balancer Outputs
output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.superblocks.load_balancer_arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.superblocks.load_balancer_dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.superblocks.load_balancer_zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.superblocks.target_group_arn
}

# Application URLs
output "superblocks_url" {
  description = "URL to access Superblocks application"
  value = var.domain != "" ? (
    var.subdomain != "" ? 
    "https://${var.subdomain}.${var.domain}" : 
    "https://${var.domain}"
  ) : "https://${module.superblocks.load_balancer_dns_name}"
}

output "load_balancer_url" {
  description = "Direct load balancer URL"
  value       = "https://${module.superblocks.load_balancer_dns_name}"
}

# SSL Certificate Outputs
output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value = var.certificate_arn != "" ? var.certificate_arn : (
    length(aws_acm_certificate.superblocks) > 0 ? aws_acm_certificate.superblocks[0].arn : null
  )
}

output "certificate_status" {
  description = "Status of the SSL certificate"
  value = length(aws_acm_certificate.superblocks) > 0 ? aws_acm_certificate.superblocks[0].status : "external"
}

# Route53 Outputs
output "route53_record_name" {
  description = "Name of the Route53 DNS record"
  value = length(aws_route53_record.superblocks) > 0 ? aws_route53_record.superblocks[0].name : null
}

output "route53_record_fqdn" {
  description = "FQDN of the Route53 DNS record"
  value = length(aws_route53_record.superblocks) > 0 ? aws_route53_record.superblocks[0].fqdn : null
}

# Monitoring Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.superblocks.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.superblocks.arn
}

output "cpu_alarm_arn" {
  description = "ARN of the CPU utilization alarm"
  value       = length(aws_cloudwatch_metric_alarm.cpu_high) > 0 ? aws_cloudwatch_metric_alarm.cpu_high[0].arn : null
}

output "memory_alarm_arn" {
  description = "ARN of the memory utilization alarm"
  value       = length(aws_cloudwatch_metric_alarm.memory_high) > 0 ? aws_cloudwatch_metric_alarm.memory_high[0].arn : null
}

# Auto Scaling Outputs
output "autoscaling_target_arn" {
  description = "ARN of the auto scaling target"
  value       = length(aws_appautoscaling_target.ecs_target) > 0 ? aws_appautoscaling_target.ecs_target[0].arn : null
}

output "autoscaling_policy_arn" {
  description = "ARN of the auto scaling policy"
  value       = length(aws_appautoscaling_policy.scale_up) > 0 ? aws_appautoscaling_policy.scale_up[0].arn : null
}

# Security Outputs
output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.superblocks.task_role_arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = module.superblocks.execution_role_arn
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter storing the agent key"
  value       = length(aws_ssm_parameter.agent_key) > 0 ? aws_ssm_parameter.agent_key[0].arn : null
}

# Network Configuration Summary
output "network_configuration" {
  description = "Summary of network configuration"
  value = {
    vpc_id                = module.superblocks.vpc_id
    load_balancer_subnets = module.superblocks.lb_subnet_ids
    ecs_subnets          = module.superblocks.ecs_subnet_ids
    security_groups      = {
      load_balancer = module.superblocks.lb_security_group_ids
      ecs_tasks     = module.superblocks.ecs_security_group_ids
    }
  }
}

# Application Configuration Summary
output "application_summary" {
  description = "Summary of Superblocks application configuration"
  value = {
    cluster_name      = module.superblocks.cluster_name
    service_name      = module.superblocks.service_name
    desired_count     = var.desired_count
    cpu_units         = var.cpu_units
    memory_units      = var.memory_units
    container_port    = var.container_port
    health_check_path = var.health_check_path
    auto_scaling = {
      enabled      = var.enable_auto_scaling
      min_capacity = var.min_capacity
      max_capacity = var.max_capacity
      target_cpu   = var.target_cpu_utilization
    }
  }
}

# Deployment Information
output "deployment_info" {
  description = "Deployment information and next steps"
  value = {
    application_url    = var.domain != "" ? (var.subdomain != "" ? "https://${var.subdomain}.${var.domain}" : "https://${var.domain}") : "https://${module.superblocks.load_balancer_dns_name}"
    load_balancer_url  = "https://${module.superblocks.load_balancer_dns_name}"
    log_group         = aws_cloudwatch_log_group.superblocks.name
    monitoring_enabled = var.enable_cloudwatch_alarms
    auto_scaling_enabled = var.enable_auto_scaling
    ssl_certificate   = var.certificate_arn != "" ? "external" : "managed"
    dns_record        = var.create_route53_record ? "managed" : "manual"
  }
}