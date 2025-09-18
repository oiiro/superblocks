# Simple Superblocks Deployment with HTTPS
# Uses superblocks_agent module with SSL enabled and self-signed certificate

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

# Superblocks Agent Module - HTTPS Configuration
module "superblocks_agent" {
  source = "../modules/superblocks_agent"

  # Basic Configuration
  name_prefix = var.project_name
  aws_region  = var.aws_region

  # Network Configuration - Use existing VPC
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  lb_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  ecs_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # Superblocks Configuration
  superblocks_agent_key         = var.superblocks_agent_key
  superblocks_agent_tags        = var.superblocks_agent_tags
  superblocks_agent_environment = var.superblocks_agent_environment

  # SSL Configuration - ENABLED with self-signed certificate
  enable_ssl      = true
  certificate_arn = var.certificate_arn  # Leave empty to auto-generate self-signed
  ssl_policy      = var.ssl_policy

  # ECS Configuration
  desired_count = var.desired_count
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity
  cpu_units     = var.cpu_units
  memory_units  = var.memory_units

  # Container Configuration
  container_image       = var.container_image
  container_port        = var.container_port
  environment_variables = var.environment_variables

  # Load Balancer Configuration
  load_balancer_internal = var.load_balancer_internal
  health_check_path      = var.health_check_path
  alb_allowed_cidrs      = var.alb_allowed_cidrs

  # Logging Configuration
  log_retention_in_days     = var.log_retention_in_days
  enable_container_insights = var.enable_container_insights

  # Auto Scaling Configuration
  enable_auto_scaling      = var.enable_auto_scaling
  target_cpu_utilization   = var.target_cpu_utilization

  # Tags
  tags = var.tags
}