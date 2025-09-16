# Superblocks Environment Configuration
# This file contains the configuration for the Superblocks deployment

# Project Configuration
project_name = "superblocks"
aws_region   = "us-east-1"

# Network Configuration
vpc_cidr              = "10.100.0.0/16"
public_subnet_count   = 2
private_subnet_count  = 2
create_nat_gateway    = true
single_nat_gateway    = false
nat_gateway_count     = 2

# Security Configuration
alb_allowed_cidrs = ["0.0.0.0/0"]  # Restrict this for production
enable_flow_logs  = true
flow_log_retention_days = 14

# Superblocks Configuration
# IMPORTANT: Replace with your actual agent key from Superblocks dashboard
superblocks_agent_key = "your-superblocks-agent-key-here"

# Domain Configuration (Optional)
# domain    = "yourdomain.com"
# subdomain = "superblocks"
# route53_zone_id = "Z1D633PJN98FT9"
# create_route53_record = true

# ECS Configuration
cluster_name         = "superblocks-cluster"
service_name         = "superblocks-service"
task_definition_name = "superblocks-task"

# Scaling Configuration
desired_count = 2
min_capacity  = 1
max_capacity  = 5

# Resource Configuration
cpu_units    = 2048  # 2 vCPU
memory_units = 4096  # 4 GB RAM

# Container Configuration
container_port = 8080
container_image = ""  # Will use default from module

# Load Balancer Configuration
load_balancer_type     = "application"
load_balancer_internal = false
health_check_path      = "/health"
health_check_port      = "traffic-port"

# SSL/TLS Configuration
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234"
ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"

# Monitoring and Logging
log_retention_in_days    = 14
enable_container_insights = true
enable_cloudwatch_alarms = true
cpu_alarm_threshold      = 80
memory_alarm_threshold   = 80

# Auto Scaling Configuration
enable_auto_scaling      = true
target_cpu_utilization   = 70
scale_in_cooldown       = 300
scale_out_cooldown      = 300

# Security Configuration
store_agent_key_in_ssm = true
enable_execute_command = false  # Enable for debugging if needed

# Cost Optimization
enable_spot_instances     = false  # Enable for cost savings
spot_instance_percentage  = 0

# Environment Variables for Superblocks Container
environment_variables = {
  # Add any custom environment variables here
  # SUPERBLOCKS_ENV = "production"
  # LOG_LEVEL = "info"
}

# Backup Configuration
enable_backup         = false
backup_retention_days = 7

# Tags
tags = {
  Project     = "Superblocks"
  Environment = "standalone"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
  Purpose     = "temporary-deployment"
  CostCenter  = "engineering"
  Deployment  = "isolated"
}