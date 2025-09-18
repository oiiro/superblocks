# Superblocks Environment Configuration
# This file contains the configuration for the Superblocks deployment

# Required Variables - Update these for your deployment
region = "us-east-1"

# Network Configuration - Use existing VPC/subnets from remote state
# vpc_id will be read from VPC remote state
# lb_subnet_ids will be read from VPC remote state (public subnets)
# ecs_subnet_ids will be read from VPC remote state (private subnets)

# Domain Configuration
domain = "superblocks.oiiro.com"
subdomain = "agent"

# Superblocks Private Agent Configuration
# IMPORTANT: Replace with your actual agent key from Superblocks dashboard
# Get from: https://app.superblocks.com -> Settings -> On-Premise Agent
superblocks_agent_key = "sb_agent_your-actual-key-here"

# Optional Variables - Can be overridden in implementations
# These have defaults in the module but can be customized

# SSL/TLS Configuration
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234"
ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"

# Tags
tags = {
  Project     = "Superblocks"
  Environment = "production"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
}