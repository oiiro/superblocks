# Simple Superblocks Deployment with HTTPS
# This version includes self-signed certificate for HTTPS without using the buggy official module

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

# Create self-signed certificate for HTTPS
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

# Import self-signed certificate to ACM
resource "aws_acm_certificate" "superblocks" {
  private_key      = tls_private_key.superblocks.private_key_pem
  certificate_body = tls_self_signed_cert.superblocks.cert_pem

  tags = merge(var.tags, {
    Name = "${var.project_name}-self-signed"
    Type = "self-signed-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "superblocks" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = var.tags
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "superblocks" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

# Application Load Balancer
resource "aws_lb" "superblocks" {
  name               = "${var.project_name}-alb"
  internal           = var.load_balancer_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = data.terraform_remote_state.vpc.outputs.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true

  tags = var.tags
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  # HTTP ingress (for redirect to HTTPS)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  # HTTPS ingress
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-sg"
  })
}

# Target Group for HTTP
resource "aws_lb_target_group" "http" {
  name        = "${var.project_name}-tg-http"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = var.tags
}

# Target Group for gRPC
resource "aws_lb_target_group" "grpc" {
  name        = "${var.project_name}-tg-grpc"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"
  protocol_version = "GRPC"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "0-99"
    port                = 8081
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = var.tags
}

# HTTP Listener (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.superblocks.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.superblocks.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = aws_acm_certificate.superblocks.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

# HTTPS Listener Rule for gRPC
resource "aws_lb_listener_rule" "grpc" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grpc.arn
  }

  condition {
    path_pattern {
      values = ["/grpc/*"]
    }
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "superblocks" {
  family                   = "${var.project_name}-agent"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.cpu_units
  memory                  = var.memory_units
  execution_role_arn      = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "superblocks-agent"
      image = "ghcr.io/superblocksteam/agent:latest"
      
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        },
        {
          containerPort = 8081
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SUPERBLOCKS_AGENT_KEY"
          value = var.superblocks_agent_key
        },
        {
          name  = "SUPERBLOCKS_AGENT_HOST_URL"
          value = "https://${aws_lb.superblocks.dns_name}"
        },
        {
          name  = "SUPERBLOCKS_AGENT_ENVIRONMENT"
          value = var.superblocks_agent_environment
        },
        {
          name  = "SUPERBLOCKS_AGENT_TAGS"
          value = var.superblocks_agent_tags
        },
        {
          name  = "SUPERBLOCKS_SERVER_URL"
          value = "https://api.superblocks.com"
        },
        {
          name  = "SUPERBLOCKS_AGENT_DATA_DOMAIN"
          value = "app.superblocks.com"
        },
        {
          name  = "SUPERBLOCKS_WORKER_LOCAL_ENABLED"
          value = "true"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.superblocks.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = var.tags
}

# ECS Service
resource "aws_ecs_service" "superblocks" {
  name            = "${var.project_name}-agent"
  cluster         = aws_ecs_cluster.superblocks.id
  task_definition = aws_ecs_task_definition.superblocks.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.http.arn
    container_name   = "superblocks-agent"
    container_port   = var.container_port
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grpc.arn
    container_name   = "superblocks-agent"
    container_port   = 8081
  }

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_execution
  ]

  tags = var.tags
}

# Auto Scaling (optional)
resource "aws_appautoscaling_target" "ecs" {
  count = var.enable_auto_scaling ? 1 : 0

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.superblocks.name}/${aws_ecs_service.superblocks.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  count = var.enable_auto_scaling ? 1 : 0

  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}