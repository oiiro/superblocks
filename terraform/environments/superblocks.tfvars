# Superblocks Environment Configuration
# This file contains the configuration for the Superblocks deployment

# Required Variables - Update these for your deployment
region = "us-east-1"

# Network Configuration - Use existing VPC/subnets from remote state OR specify directly
# Option 1: Leave commented to use VPC remote state (default)
# Option 2: Uncomment and provide specific IDs for your environment

vpc_id = "vpc-099901fb8308ce0c7"    # Your VPC ID
lb_subnet_ids = [
  "subnet-111111111aaaaaaa",       # Public subnet 1 (for load balancer)
  "subnet-222222222bbbbbb"         # Public subnet 2 (for load balancer)
]
ecs_subnet_ids = [
  "subnet-333333333cccccc",        # Private subnet 1 (for ECS tasks)
  "subnet-444444444dddddd"         # Private subnet 2 (for ECS tasks)
]

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