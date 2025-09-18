# Variables for Superblocks Agent Module

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "lb_subnet_ids" {
  description = "Subnet IDs for the load balancer"
  type        = list(string)
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
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
  description = "Superblocks agent key for authentication (only if not using secrets_manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "agent_key_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing the agent key"
  type        = string
  default     = ""
}

variable "superblocks_agent_tags" {
  description = "Tags for Superblocks agent"
  type        = string
  default     = "profile:*"
}

variable "superblocks_agent_environment" {
  description = "Superblocks agent environment"
  type        = string
  default     = "*"
}

# SSL Configuration
variable "enable_ssl" {
  description = "Enable SSL/HTTPS"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of existing SSL certificate (leave empty to create self-signed)"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for the load balancer"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# ECS Configuration
variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 3
}

variable "cpu_units" {
  description = "CPU units for task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "memory_units" {
  description = "Memory in MiB"
  type        = number
  default     = 2048
}

# Container Configuration
variable "container_image" {
  description = "Docker image for Superblocks container"
  type        = string
  default     = "ghcr.io/superblocksteam/agent:v1.27.0"
}

variable "container_port" {
  description = "Port for the container"
  type        = number
  default     = 8080
}

variable "environment_variables" {
  description = "Additional environment variables for the container"
  type        = map(string)
  default     = {}
}

# Load Balancer Configuration
variable "load_balancer_internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "alb_allowed_cidrs" {
  description = "Allowed CIDR blocks for ALB access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Logging
variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_container_insights" {
  description = "Enable Container Insights"
  type        = bool
  default     = true
}

# Auto Scaling
variable "enable_auto_scaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = true
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}