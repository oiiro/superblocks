# Outputs for Simple Superblocks Deployment

output "agent_url" {
  description = "URL to access the Superblocks agent"
  value       = "http://${aws_lb.superblocks.dns_name}"
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.superblocks.dns_name
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
    url    = "http://${aws_lb.superblocks.dns_name}"
    method = var.load_balancer_internal ? "VPC access only" : "Public internet access"
    health = "http://${aws_lb.superblocks.dns_name}/health"
    note   = "Add this URL to your Superblocks dashboard as the agent host"
  }
}