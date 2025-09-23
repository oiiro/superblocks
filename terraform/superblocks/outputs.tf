# Outputs for Superblocks Deployment

output "agent_url" {
  description = "URL to access the Superblocks agent"
  value       = "https://${var.subdomain}.${var.domain}"
}

output "load_balancer_dns" {
  description = "ALB DNS name (for Route53 setup)"
  value       = module.superblocks_agent.load_balancer_dns_name
}

output "route53_setup" {
  description = "Route53 configuration needed"
  value       = <<EOT

✅ Deployment complete! Now set up Route53:

1. Go to Route53 in AWS Console
2. Find your hosted zone for: ${var.domain}
3. Create new record:
   - Name: ${var.subdomain}
   - Type: CNAME
   - Value: ${module.superblocks_agent.load_balancer_dns_name}

4. Add agent URL to Superblocks dashboard:
   https://${var.subdomain}.${var.domain}

EOT
}

output "container_environment_variables" {
  description = "All environment variables configured in the ECS task definition container (final values after overrides)"
  value       = module.superblocks_agent.container_environment_variables
}

output "environment_variable_precedence" {
  description = "Shows which built-in variables are overridden by your custom environment_variables"
  value       = module.superblocks_agent.environment_variable_precedence
}