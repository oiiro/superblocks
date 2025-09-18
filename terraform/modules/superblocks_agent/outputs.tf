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
  value       = aws_ecs_service.superblocks.arn
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