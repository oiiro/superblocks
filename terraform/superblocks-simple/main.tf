# Simple Superblocks Deployment (HTTP only)
# Uses superblocks_agent module with SSL disabled

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
  region = var.region
}

# Data source for VPC configuration
data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}

# Superblocks Agent Module - HTTP Configuration
module "superblocks_agent" {
  source = "../modules/superblocks_agent"

  # Required Configuration
  name_prefix = "superblocks"
  region      = var.region

  # Network Configuration - Use existing VPC or direct variables
  vpc_id         = var.vpc_id != "" ? var.vpc_id : data.terraform_remote_state.vpc.outputs.vpc_id
  lb_subnet_ids  = length(var.lb_subnet_ids) > 0 ? var.lb_subnet_ids : data.terraform_remote_state.vpc.outputs.public_subnet_ids
  ecs_subnet_ids = length(var.ecs_subnet_ids) > 0 ? var.ecs_subnet_ids : data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # Domain Configuration
  domain    = var.domain
  subdomain = var.subdomain

  # Superblocks Configuration
  superblocks_agent_key = var.superblocks_agent_key

  # SSL Configuration - DISABLED for HTTP-only
  enable_ssl      = false
  certificate_arn = ""
  ssl_policy      = var.ssl_policy

  # Tags
  tags = var.tags
}