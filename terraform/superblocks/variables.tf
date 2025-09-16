# Variables for Superblocks Deployment

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

variable "domain" {
  description = "Domain name for Superblocks application"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for Superblocks application"
  type        = string
  default     = "app"
}

# ECS Configuration
variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = ""
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = ""
}

variable "task_definition_name" {
  description = "Name of the ECS task definition"
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 2
  
  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 100
    error_message = "Desired count must be between 1 and 100."
  }
}

variable "min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_capacity >= 1
    error_message = "Minimum capacity must be at least 1."
  }
}

variable "max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 10
  
  validation {
    condition     = var.max_capacity >= 1
    error_message = "Maximum capacity must be at least 1."
  }
}

variable "cpu_units" {
  description = "CPU units for the task definition (1024 = 1 vCPU)"
  type        = number
  default     = 2048
  
  validation {
    condition = contains([
      256, 512, 1024, 2048, 4096, 8192, 16384
    ], var.cpu_units)
    error_message = "CPU units must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384."
  }
}

variable "memory_units" {
  description = "Memory units for the task definition (in MiB)"
  type        = number
  default     = 4096
  
  validation {
    condition     = var.memory_units >= 512 && var.memory_units <= 30720
    error_message = "Memory units must be between 512 and 30720 MiB."
  }
}

# Container Configuration
variable "container_image" {
  description = "Docker image for Superblocks container"
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Port on which the container runs"
  type        = number
  default     = 8080
}

variable "environment_variables" {
  description = "Environment variables for the Superblocks container"
  type        = map(string)
  default     = {}
}

# Load Balancer Configuration
variable "load_balancer_type" {
  description = "Type of load balancer (application or network)"
  type        = string
  default     = "application"
  
  validation {
    condition     = contains(["application", "network"], var.load_balancer_type)
    error_message = "Load balancer type must be either 'application' or 'network'."
  }
}

variable "load_balancer_internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Health check path for the load balancer"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Health check port for the load balancer"
  type        = string
  default     = "traffic-port"
}

# SSL/TLS Configuration
variable "certificate_arn" {
  description = "ARN of existing SSL certificate (leave empty to create new)"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for the load balancer"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "certificate_subject_alternative_names" {
  description = "Subject alternative names for the SSL certificate"
  type        = list(string)
  default     = []
}

# Route53 Configuration
variable "create_route53_record" {
  description = "Whether to create Route53 DNS record"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record"
  type        = string
  default     = ""
}

# Logging Configuration
variable "log_retention_in_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

# Monitoring and Alerting
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cpu_alarm_threshold >= 1 && var.cpu_alarm_threshold <= 100
    error_message = "CPU alarm threshold must be between 1 and 100."
  }
}

variable "memory_alarm_threshold" {
  description = "Memory utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.memory_alarm_threshold >= 1 && var.memory_alarm_threshold <= 100
    error_message = "Memory alarm threshold must be between 1 and 100."
  }
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

# Auto Scaling Configuration
variable "enable_auto_scaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = true
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
  
  validation {
    condition     = var.target_cpu_utilization >= 1 && var.target_cpu_utilization <= 100
    error_message = "Target CPU utilization must be between 1 and 100."
  }
}

variable "scale_in_cooldown" {
  description = "Cooldown period for scale in actions (seconds)"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period for scale out actions (seconds)"
  type        = number
  default     = 300
}

# Security Configuration
variable "store_agent_key_in_ssm" {
  description = "Store Superblocks agent key in Systems Manager Parameter Store"
  type        = bool
  default     = true
}

# Backup and Recovery
variable "enable_backup" {
  description = "Enable AWS Backup for ECS cluster"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Use Spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "spot_instance_percentage" {
  description = "Percentage of capacity to run on Spot instances"
  type        = number
  default     = 50
  
  validation {
    condition     = var.spot_instance_percentage >= 0 && var.spot_instance_percentage <= 100
    error_message = "Spot instance percentage must be between 0 and 100."
  }
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Superblocks"
    Environment = "standalone"
    ManagedBy   = "terraform"
  }
}

# Advanced Configuration
variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "enable_service_discovery" {
  description = "Enable AWS Cloud Map service discovery"
  type        = bool
  default     = false
}

variable "service_discovery_namespace" {
  description = "Service discovery namespace"
  type        = string
  default     = "superblocks.local"
}