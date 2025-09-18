# Outputs for Simple HTTPS Superblocks Deployment

# Primary outputs
output "agent_url" {
  description = "URL to access the Superblocks agent (HTTPS)"
  value       = module.superblocks_agent.agent_url
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.superblocks_agent.load_balancer_dns_name
}

# SSL Certificate information
output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = module.superblocks_agent.certificate_arn
}

output "certificate_warning" {
  description = "SSL certificate warning"
  value       = module.superblocks_agent.certificate_warning
}

# Infrastructure details
output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.superblocks_agent.cluster_name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.superblocks_agent.service_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.superblocks_agent.vpc_id
}

# Security groups
output "lb_security_group_id" {
  description = "Load balancer security group ID"
  value       = module.superblocks_agent.lb_security_group_id
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = module.superblocks_agent.ecs_security_group_id
}

# Monitoring
output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.superblocks_agent.log_group_name
}

# Access instructions
output "access_instructions" {
  description = "How to access Superblocks"
  value = {
    url         = module.superblocks_agent.agent_url
    method      = var.load_balancer_internal ? "VPC access only" : "Public internet access"
    health      = "${module.superblocks_agent.agent_url}/health"
    protocol    = "HTTPS with self-signed certificate"
    ssl_warning = "You will see SSL warnings - click 'Advanced' and 'Proceed' to bypass"
    dashboard   = "Add this URL to your Superblocks dashboard as the agent host"
    curl_test   = "curl -k ${module.superblocks_agent.agent_url}/health"
  }
}