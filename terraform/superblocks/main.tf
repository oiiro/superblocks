# Main Superblocks Deployment Configuration
# This module deploys Superblocks using the official Terraform modules

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
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

# Superblocks ECS Module
module "superblocks" {
  source = "github.com/superblocksteam/terraform-aws-superblocks"

  # Required variables
  superblocks_agent_key = var.superblocks_agent_key
  vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  lb_subnet_ids         = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  ecs_subnet_ids        = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # Domain configuration
  domain    = var.domain
  subdomain = var.subdomain

  # ECS Configuration
  cluster_name         = var.cluster_name
  service_name         = var.service_name
  task_definition_name = var.task_definition_name

  # Scaling configuration
  desired_count = var.desired_count
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity

  # Instance configuration
  cpu_units    = var.cpu_units
  memory_units = var.memory_units

  # Load balancer configuration
  load_balancer_type     = var.load_balancer_type
  load_balancer_internal = var.load_balancer_internal
  health_check_path      = var.health_check_path
  health_check_port      = var.health_check_port

  # Security configuration
  lb_security_group_ids  = [data.terraform_remote_state.vpc.outputs.alb_security_group_id]
  ecs_security_group_ids = [data.terraform_remote_state.vpc.outputs.ecs_security_group_id]

  # SSL/TLS configuration
  certificate_arn = var.certificate_arn
  ssl_policy      = var.ssl_policy

  # Environment variables for Superblocks
  environment_variables = var.environment_variables

  # Container image configuration
  container_image = var.container_image
  container_port  = var.container_port

  # Logging configuration
  log_group_name              = "/ecs/${var.project_name}"
  log_retention_in_days       = var.log_retention_in_days
  enable_container_insights   = var.enable_container_insights

  # Tags
  tags = var.tags
}

# CloudWatch Log Group for ECS Tasks
resource "aws_cloudwatch_log_group" "superblocks" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_in_days

  tags = merge(var.tags, {
    Name    = "${var.project_name}-logs"
    Service = "superblocks"
    Type    = "cloudwatch-log-group"
  })
}

# CloudWatch Alarms for Monitoring
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
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ServiceName = module.superblocks.service_name
    ClusterName = module.superblocks.cluster_name
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
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ServiceName = module.superblocks.service_name
    ClusterName = module.superblocks.cluster_name
  }

  tags = var.tags
}

# Application Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  count = var.enable_auto_scaling ? 1 : 0

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${module.superblocks.cluster_name}/${module.superblocks.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.tags
}

# Auto Scaling Policy - Scale Up
resource "aws_appautoscaling_policy" "scale_up" {
  count = var.enable_auto_scaling ? 1 : 0

  name               = "${var.project_name}-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.target_cpu_utilization

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# Route53 Record (if domain is provided)
resource "aws_route53_record" "superblocks" {
  count = var.create_route53_record && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain}" : var.domain
  type    = "A"

  alias {
    name                   = module.superblocks.load_balancer_dns_name
    zone_id                = module.superblocks.load_balancer_zone_id
    evaluate_target_health = true
  }

  tags = var.tags
}

# SSL Certificate (if not provided)
resource "aws_acm_certificate" "superblocks" {
  count = var.certificate_arn == "" && var.domain != "" ? 1 : 0

  domain_name       = var.subdomain != "" ? "${var.subdomain}.${var.domain}" : var.domain
  validation_method = "DNS"

  subject_alternative_names = var.certificate_subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-certificate"
    Type = "ssl-certificate"
  })
}

# Certificate validation
resource "aws_acm_certificate_validation" "superblocks" {
  count = var.certificate_arn == "" && var.domain != "" && var.route53_zone_id != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.superblocks[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Route53 records for certificate validation
resource "aws_route53_record" "certificate_validation" {
  for_each = var.certificate_arn == "" && var.domain != "" && var.route53_zone_id != "" ? {
    for dvo in aws_acm_certificate.superblocks[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Systems Manager Parameter for Agent Key (encrypted)
resource "aws_ssm_parameter" "agent_key" {
  count = var.store_agent_key_in_ssm ? 1 : 0

  name  = "/${var.project_name}/superblocks/agent-key"
  type  = "SecureString"
  value = var.superblocks_agent_key

  tags = merge(var.tags, {
    Name        = "${var.project_name}-agent-key"
    Type        = "ssm-parameter"
    Sensitive   = "true"
  })
}