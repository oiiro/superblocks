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

# Security Groups (if exposed by module)
output "security_group_ids" {
  description = "Security group IDs"
  value = {
    info = "Security groups managed by Superblocks module"
  }
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
    agent_status = "Deployed with self-signed certificate (SSL warnings expected)"
    next_steps = "1. Access URL and bypass SSL warning\n2. Configure agent in Superblocks dashboard using the agent_url"
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Configuration parameters used"
  value = {
    container_cpu = var.cpu_units
    container_memory = var.memory_units
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
    auto_scaling_enabled = var.enable_auto_scaling
  }
}

# SSM Parameter (if created)
output "ssm_parameter_name" {
  description = "SSM parameter storing the agent key"
  value       = var.store_agent_key_in_ssm ? "/${var.project_name}/superblocks/agent-key" : "Not stored in SSM"
}