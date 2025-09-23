# --- variables.tf ---
# Input variables for Aurora MySQL Serverless v2 with Bastion module

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Aurora database"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for bastion host"
  type        = list(string)
}

# Security Configuration
variable "ecs_service_sg_id" {
  description = "Security group ID of ECS service that needs database access"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "List of CIDR blocks for admin SSH access (NOT recommended - use SSM instead)"
  type        = list(string)
  default     = []
}

# Project Configuration
variable "project_name" {
  description = "Project name for tagging and naming resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# Aurora Configuration
variable "aurora_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "serverless_min_acu" {
  description = "Minimum ACUs for Aurora Serverless v2"
  type        = number
  default     = 0.5
  validation {
    condition     = var.serverless_min_acu >= 0.5 && var.serverless_min_acu <= 128
    error_message = "Serverless min ACU must be between 0.5 and 128"
  }
}

variable "serverless_max_acu" {
  description = "Maximum ACUs for Aurora Serverless v2"
  type        = number
  default     = 1
  validation {
    condition     = var.serverless_max_acu >= 0.5 && var.serverless_max_acu <= 128
    error_message = "Serverless max ACU must be between 0.5 and 128"
  }
}

variable "enable_provisioned_instead_of_serverless" {
  description = "Use provisioned instances instead of serverless"
  type        = bool
  default     = false
}

variable "provisioned_instance_class" {
  description = "Instance class for provisioned Aurora instances"
  type        = string
  default     = "db.t3.medium"
}

# Database Configuration
variable "db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "wegdemodb"
  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,63}$", var.db_name))
    error_message = "Database name must start with a letter and contain only lowercase letters, numbers, and underscores (max 64 chars)"
  }
}

variable "db_master_username" {
  description = "Master username for the database"
  type        = string
  default     = "wegdbadmin"
  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,15}$", var.db_master_username))
    error_message = "Master username must start with a letter and contain only lowercase letters, numbers, and underscores (max 16 chars)"
  }
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Enable deletion protection (should be true for production)"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "enhanced_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable)"
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.enhanced_monitoring_interval)
    error_message = "Enhanced monitoring interval must be 0, 1, 5, 10, 15, 30, or 60"
  }
}

# Bastion Configuration
variable "instance_type_bastion" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "enable_bastion" {
  description = "Whether to create a bastion host"
  type        = bool
  default     = true
}

# Additional Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}