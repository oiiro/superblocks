# Main Superblocks Private Agent Deployment Configuration
# This module deploys Superblocks private agent using the official Terraform module

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

# Create a self-signed certificate for the ALB (workaround for HTTPS requirement)
resource "tls_private_key" "superblocks" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "superblocks" {
  private_key_pem = tls_private_key.superblocks.private_key_pem

  subject {
    common_name  = "superblocks.local"
    organization = "Superblocks"
  }

  validity_period_hours = 8760  # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "superblocks" {
  private_key      = tls_private_key.superblocks.private_key_pem
  certificate_body = tls_self_signed_cert.superblocks.cert_pem

  tags = merge(var.tags, {
    Name = "${var.project_name}-self-signed"
    Type = "self-signed-certificate"
  })
}

# Simplified Superblocks Terraform Module
module "superblocks" {
  source  = "superblocksteam/superblocks/aws"
  version = "~> 1.0"

  # Core Configuration
  superblocks_agent_key = var.superblocks_agent_key
  
  # Provide dummy domain to avoid HTTPS listener issues
  domain    = "superblocks.local"
  subdomain = "agent"

  # Network Configuration - Use existing VPC
  create_vpc     = false
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  lb_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids   # Public ALB for easier access
  ecs_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # Load Balancer Configuration
  create_lb   = true
  lb_internal = var.load_balancer_internal  # Configurable internal/external

  # DNS and Certificate Configuration
  create_dns   = false  # No Route53 integration
  create_certs = false  # Use our self-signed certificate
  certificate_arn = aws_acm_certificate.superblocks.arn  # Provide self-signed cert

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

# Note: Monitoring is handled by the Superblocks module
# CloudWatch alarms can be added separately if needed

# Note: Agent key is passed directly to the module
# SSM parameter storage can be added if needed