# --- variables.tf ---
# Input variables for DynamoDB table with ECS access

# Required Variables
variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.table_name))
    error_message = "Table name must contain only alphanumeric characters, underscores, hyphens, and dots"
  }
}

variable "hash_key" {
  description = "Attribute to use as the hash (partition) key"
  type        = string
}

variable "range_key" {
  description = "Attribute to use as the range (sort) key. Leave empty for no range key."
  type        = string
  default     = ""
}

variable "app_name" {
  description = "Application name for tagging and resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "App name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "ecs_task_role_name" {
  description = "Name of the ECS task IAM role that needs DynamoDB access"
  type        = string
}

variable "additional_role_names" {
  description = "Additional IAM role names that need DynamoDB access (e.g., bastion role, lambda roles)"
  type        = list(string)
  default     = []
}

# Optional Variables with Sensible Defaults
variable "hash_key_type" {
  description = "Type of the hash key attribute (S = String, N = Number, B = Binary)"
  type        = string
  default     = "S"
  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "Hash key type must be S (String), N (Number), or B (Binary)"
  }
}

variable "range_key_type" {
  description = "Type of the range key attribute (S = String, N = Number, B = Binary)"
  type        = string
  default     = "S"
  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "Range key type must be S (String), N (Number), or B (Binary)"
  }
}
