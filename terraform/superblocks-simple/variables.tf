# Variables for Simple Superblocks Deployment

# Required Variables
variable "region" {
  description = "AWS region for resource deployment"
  type        = string
}

# Network Configuration - Optional, will use VPC remote state if not provided
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
  default     = ""
}

variable "lb_subnet_ids" {
  description = "Subnet IDs for the load balancer"
  type        = list(string)
  default     = []
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
  default     = []
}

# Domain Configuration
variable "domain" {
  description = "Domain name for the agent"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for the agent"
  type        = string
  default     = "agent"
}

# Superblocks Configuration
variable "superblocks_agent_key" {
  description = "Superblocks agent key for authentication"
  type        = string
  sensitive   = true
}

# SSL Configuration
variable "ssl_policy" {
  description = "SSL policy for the load balancer"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# Load Balancer Configuration
variable "load_balancer_internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project   = "Superblocks"
    ManagedBy = "terraform"
  }
}