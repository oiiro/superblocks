# Minimal Variables - Only what's required by Superblocks

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Network Configuration (Required)
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "lb_subnet_ids" {
  description = "Subnet IDs for the load balancer (typically public subnets)"
  type        = list(string)
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for ECS tasks (typically private subnets)"
  type        = list(string)
}

# Domain Configuration (Required)
variable "domain" {
  description = "Your domain name"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the Superblocks agent"
  type        = string
}

# Superblocks Configuration (Required)
variable "superblocks_agent_key" {
  description = "Superblocks agent key from dashboard"
  type        = string
  sensitive   = true
}

# Optional - SSL Certificate
variable "certificate_arn" {
  description = "ACM certificate ARN. Leave empty for self-signed certificate"
  type        = string
  default     = ""
}