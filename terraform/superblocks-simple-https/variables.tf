# Variables for Simple HTTPS Superblocks Deployment

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "superblocks"
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

# Superblocks Configuration
variable "superblocks_agent_key" {
  description = "Superblocks agent key for authentication"
  type        = string
  sensitive   = true
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
variable "container_port" {
  description = "Port for the container"
  type        = number
  default     = 8080
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

# SSL Configuration
variable "ssl_policy" {
  description = "SSL policy for the load balancer"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
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
  default = {
    Project   = "Superblocks"
    ManagedBy = "terraform"
  }
}