# Main Superblocks Private Agent Deployment Configuration
# This module deploys Superblocks private agent using the official Terraform module

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data source for VPC configuration
data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}

# Data source for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Simplified Superblocks Terraform Module - No Route53
module "superblocks" {
  source  = "superblocksteam/superblocks/aws"
  version = "~> 1.0"

  # Core Configuration
  superblocks_agent_key = var.superblocks_agent_key

  # Network Configuration - Use existing VPC
  create_vpc     = false
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  lb_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids   # Public ALB for easier access
  ecs_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # Load Balancer Configuration
  create_lb   = true
  lb_internal = var.load_balancer_internal  # Configurable internal/external

  # DNS and Certificate Configuration - DISABLED
  create_dns   = false  # No Route53 integration
  create_certs = false  # No ACM certificates

  # Container Configuration
  container_cpu           = var.cpu_units
  container_memory        = var.memory_units
  container_min_capacity  = var.min_capacity
  container_max_capacity  = var.max_capacity

  # Agent Specific Configuration
  superblocks_server_url        = "https://api.superblocks.com"
  superblocks_agent_data_domain = "app.superblocks.com"
  superblocks_agent_tags        = var.superblocks_agent_tags
  superblocks_agent_environment = var.superblocks_agent_environment

  # Security Configuration
  create_lb_sg = true
  
  # Resource Naming
  name_prefix = var.project_name

  # Tags
  tags = var.tags
}

# Monitoring and Alerting (Optional)
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Superblocks ECS CPU utilization high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ServiceName = "${var.project_name}-agent"  # Official module naming
    ClusterName = "${var.project_name}-cluster"
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "Superblocks ECS memory utilization high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ServiceName = "${var.project_name}-agent"
    ClusterName = "${var.project_name}-cluster"
  }

  tags = var.tags
}

# Systems Manager Parameter for Agent Key (encrypted)
resource "aws_ssm_parameter" "agent_key" {
  count = var.store_agent_key_in_ssm ? 1 : 0

  name  = "/${var.project_name}/superblocks/agent-key"
  type  = "SecureString"
  value = var.superblocks_agent_key

  tags = merge(var.tags, {
    Name      = "${var.project_name}-agent-key"
    Type      = "ssm-parameter"
    Sensitive = "true"
  })
}