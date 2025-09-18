# Superblocks Agent Module
# Reusable module for deploying Superblocks agent with configurable options

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

locals {
  # Determine protocol based on SSL configuration
  protocol = var.enable_ssl ? "https" : "http"
  port     = var.enable_ssl ? 443 : 80

  # Determine if using Secrets Manager
  use_secrets_manager = var.agent_key_secret_arn != ""
}

# Data source for Secrets Manager secret (if using)
data "aws_secretsmanager_secret" "agent_key" {
  count = local.use_secrets_manager ? 1 : 0
  arn   = var.agent_key_secret_arn
}

# Self-signed certificate (only if SSL enabled and no certificate provided)
resource "tls_private_key" "superblocks" {
  count = var.enable_ssl && var.certificate_arn == "" ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "superblocks" {
  count = var.enable_ssl && var.certificate_arn == "" ? 1 : 0

  private_key_pem = tls_private_key.superblocks[0].private_key_pem

  subject {
    common_name  = "superblocks.local"
    organization = "Superblocks"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "superblocks" {
  count = var.enable_ssl && var.certificate_arn == "" ? 1 : 0

  private_key      = tls_private_key.superblocks[0].private_key_pem
  certificate_body = tls_self_signed_cert.superblocks[0].cert_pem

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-self-signed"
    Type = "self-signed-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "superblocks" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = var.tags
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution" {
  name = "${var.name_prefix}-ecs-execution"

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
  name = "${var.name_prefix}-ecs-task"

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

# IAM Policy for Secrets Manager access (if using secrets)
resource "aws_iam_role_policy" "ecs_task_secrets" {
  count = local.use_secrets_manager ? 1 : 0
  name  = "${var.name_prefix}-secrets-policy"
  role  = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.agent_key_secret_arn
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "superblocks" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

# Application Load Balancer
resource "aws_lb" "superblocks" {
  name               = "${var.name_prefix}-alb"
  internal           = var.load_balancer_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.lb_subnet_ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = var.tags
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = var.vpc_id

  # HTTP ingress
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  # HTTPS ingress (only if SSL enabled)
  dynamic "ingress" {
    for_each = var.enable_ssl ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.alb_allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name_prefix = "${var.name_prefix}-ecs-"
  vpc_id      = var.vpc_id

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
    Name = "${var.name_prefix}-ecs-sg"
  })
}

# Target Group for HTTP
resource "aws_lb_target_group" "http" {
  name        = "${var.name_prefix}-tg-http"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
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

# Target Group for gRPC (only for HTTPS - GRPC requires TLS)
resource "aws_lb_target_group" "grpc" {
  count = var.enable_ssl ? 1 : 0

  name             = "${var.name_prefix}-tg-grpc"
  port             = 8081
  protocol         = "HTTP"
  vpc_id           = var.vpc_id
  target_type      = "ip"
  protocol_version = "GRPC"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "0-99" # GRPC status codes
    port                = 8081
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = var.tags
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.superblocks.arn
  port              = "80"
  protocol          = "HTTP"

  # If SSL enabled, redirect to HTTPS, otherwise forward to target group
  dynamic "default_action" {
    for_each = var.enable_ssl ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.enable_ssl ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.http.arn
    }
  }
}

# HTTPS Listener (only if SSL enabled)
resource "aws_lb_listener" "https" {
  count = var.enable_ssl ? 1 : 0

  load_balancer_arn = aws_lb.superblocks.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn != "" ? var.certificate_arn : aws_acm_certificate.superblocks[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

# HTTP Listener Rule for gRPC - DISABLED (GRPC requires HTTPS/TLS)
resource "aws_lb_listener_rule" "grpc_http" {
  count = 0 # Always disabled - GRPC cannot work with HTTP listeners

  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn # Placeholder - never used
  }

  condition {
    path_pattern {
      values = ["/grpc/*", "/_grpc/*"]
    }
  }
}

# HTTPS Listener Rule for gRPC (only if SSL enabled)
resource "aws_lb_listener_rule" "grpc_https" {
  count = var.enable_ssl ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grpc[0].arn
  }

  condition {
    path_pattern {
      values = ["/grpc/*", "/_grpc/*"]
    }
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "superblocks" {
  family                   = "${var.name_prefix}-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu_units
  memory                   = var.memory_units
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "superblocks-agent"
      image = var.container_image

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

      environment = concat([
        {
          name  = "SUPERBLOCKS_AGENT_HOST_URL"
          value = var.domain != "" && var.subdomain != "" ? "${local.protocol}://${var.subdomain}.${var.domain}" : "${local.protocol}://${aws_lb.superblocks.dns_name}"
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
        ], local.use_secrets_manager ? [] : [{
          name  = "SUPERBLOCKS_AGENT_KEY"
          value = var.superblocks_agent_key
        }], [
        for k, v in var.environment_variables : {
          name  = k
          value = v
        }
      ])

      # Use Secrets Manager for agent key if configured
      secrets = local.use_secrets_manager ? [{
        name      = "SUPERBLOCKS_AGENT_KEY"
        valueFrom = var.agent_key_secret_arn
      }] : []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.superblocks.name
          "awslogs-region"        = var.region
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
  name            = "${var.name_prefix}-agent"
  cluster         = aws_ecs_cluster.superblocks.id
  task_definition = aws_ecs_task_definition.superblocks.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.ecs_subnet_ids
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.http.arn
    container_name   = "superblocks-agent"
    container_port   = var.container_port
  }

  # GRPC load balancer only when SSL is enabled
  dynamic "load_balancer" {
    for_each = var.enable_ssl ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.grpc[0].arn
      container_name   = "superblocks-agent"
      container_port   = 8081
    }
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.grpc_http,
    aws_lb_listener_rule.grpc_https,
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

  name               = "${var.name_prefix}-cpu-scaling"
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