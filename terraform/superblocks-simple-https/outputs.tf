# Outputs for Simple HTTPS Superblocks Deployment

output "agent_url" {
  description = "URL to access the Superblocks agent (HTTPS)"
  value       = "https://${aws_lb.superblocks.dns_name}"
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.superblocks.dns_name
}

output "certificate_arn" {
  description = "ARN of the self-signed certificate"
  value       = aws_acm_certificate.superblocks.arn
}

output "certificate_warning" {
  description = "SSL certificate warning"
  value       = "WARNING: Using self-signed certificate. You will see SSL warnings in your browser. Click 'Advanced' and 'Proceed' to bypass."
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.superblocks.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.superblocks.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = data.terraform_remote_state.vpc.outputs.vpc_id
}

output "access_instructions" {
  description = "How to access Superblocks"
  value = {
    url        = "https://${aws_lb.superblocks.dns_name}"
    method     = var.load_balancer_internal ? "VPC access only" : "Public internet access"
    health     = "https://${aws_lb.superblocks.dns_name}/health"
    ssl_note   = "Self-signed certificate - bypass SSL warnings in browser"
    curl_test  = "curl -k https://${aws_lb.superblocks.dns_name}/health"
    dashboard  = "Add this URL to your Superblocks dashboard as the agent host"
  }
}