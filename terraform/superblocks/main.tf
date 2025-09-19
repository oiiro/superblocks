# Minimal Superblocks Deployment
# Uses existing VPC and subnets with minimal customization

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Deploy Superblocks using the agent module with minimal config
module "superblocks_agent" {
  source = "../modules/superblocks_agent"

  # Required Configuration
  name_prefix = "superblocks"
  region      = var.region

  # Network Configuration (Required)
  vpc_id         = var.vpc_id
  lb_subnet_ids  = var.lb_subnet_ids
  ecs_subnet_ids = var.ecs_subnet_ids

  # Domain Configuration (Required)
  domain    = var.domain
  subdomain = var.subdomain

  # Superblocks Agent Key Configuration
  superblocks_agent_key = var.superblocks_agent_key
  agent_key_secret_arn  = var.agent_key_secret_arn

  # Environment variables to handle self-signed certificate
  environment_variables = {
    SUPERBLOCKS_AGENT_TLS_INSECURE = "true"
  }

  # SSL Configuration (Always use HTTPS for production)
  enable_ssl      = true
  certificate_arn = var.certificate_arn # Empty = self-signed

  # Use all other defaults from the module
  tags = {
    Project     = "Superblocks"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}