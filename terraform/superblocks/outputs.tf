# Outputs for Simplified Superblocks Deployment

# Agent Access Information
output "agent_url" {
  description = "Load balancer URL to access the Superblocks agent"
  value       = "https://${module.superblocks.lb_dns_name}"
}

output "load_balancer_dns_name" {
  description = "Load balancer DNS name (use this to access the agent)"
  value       = module.superblocks.lb_dns_name
}

output "certificate_warning" {
  description = "Certificate information"
  value       = "WARNING: Using self-signed certificate. You may need to bypass SSL warnings in your browser."
}

# Infrastructure Details
output "vpc_id" {
  description = "VPC ID where Superblocks is deployed"
  value       = module.superblocks.vpc_id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = "${var.project_name}-cluster"
}

output "service_name" {
  description = "ECS service name"
  value       = "${var.project_name}-agent"
}

# Security Groups
output "lb_security_group_ids" {
  description = "Load balancer security group IDs"
  value       = module.superblocks.lb_security_group_ids
}

output "ecs_security_group_ids" {
  description = "ECS security group IDs"
  value       = module.superblocks.ecs_security_group_ids
}

# Access Instructions
output "access_instructions" {
  description = "How to access the Superblocks agent"
  value = {
    method = var.load_balancer_internal ? "Internal VPC access only" : "Public internet access"
    url = "https://${module.superblocks.lb_dns_name}"
    note = var.load_balancer_internal ? "Access requires VPN connection or bastion host" : "Accessible from internet"
    security = "Self-signed certificate - You will see SSL warnings (this is expected)"
    bypass_warning = "Click 'Advanced' and 'Proceed' to bypass SSL warning in browser"
  }
}

# Network Information
output "subnet_ids" {
  description = "Subnet IDs used for deployment"
  value = {
    lb_subnets  = module.superblocks.lb_subnet_ids
    ecs_subnets = module.superblocks.ecs_subnet_ids
  }
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of the Superblocks deployment"
  value = {
    agent_url = "https://${module.superblocks.lb_dns_name}"
    load_balancer_type = var.load_balancer_internal ? "Internal (VPC only)" : "Public (Internet accessible)"
    vpc_id = module.superblocks.vpc_id
    cluster_name = "${var.project_name}-cluster"
    service_name = "${var.project_name}-agent"
    agent_status = "Deployed with self-signed certificate (SSL warnings expected)"
    next_steps = "1. Access URL and bypass SSL warning\n2. Configure agent in Superblocks dashboard using the agent_url"
  }
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