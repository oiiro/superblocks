# --- main.tf ---
# Aurora MySQL Serverless v2 with Bastion Host and Secrets Manager

locals {
  name_prefix = "${var.project_name}-${var.env}"

  common_tags = merge(
    {
      Name        = local.name_prefix
      Project     = var.project_name
      Environment = var.env
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )

  # Determine if we're using serverless or provisioned
  is_serverless = !var.enable_provisioned_instead_of_serverless
}

# ===== SECRETS MANAGER =====

# Generate random password for database master user
resource "random_password" "db_master" {
  length  = 24
  special = true
  # Avoid problematic special characters for MySQL
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix = "${local.name_prefix}-aurora-master-"
  description = "Master credentials for ${local.name_prefix} Aurora cluster"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-secret"
    Type = "database-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master.result
    engine   = "mysql"
    host     = aws_rds_cluster.aurora_mysql.endpoint
    port     = aws_rds_cluster.aurora_mysql.port
    dbname   = var.db_name
  })
}

# ===== SECURITY GROUPS =====

# Security group for Aurora
resource "aws_security_group" "aurora" {
  name_prefix = "${local.name_prefix}-aurora-"
  description = "Security group for Aurora MySQL cluster"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-sg"
    Type = "database"
  })
}

# Allow MySQL access from ECS service
resource "aws_security_group_rule" "aurora_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.ecs_service_sg_id
  security_group_id        = aws_security_group.aurora.id
  description              = "MySQL access from ECS service"
}

# Allow MySQL access from bastion
resource "aws_security_group_rule" "aurora_from_bastion" {
  count = var.enable_bastion ? 1 : 0

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion[0].id
  security_group_id        = aws_security_group.aurora.id
  description              = "MySQL access from bastion host"
}

# Allow all egress from Aurora
resource "aws_security_group_rule" "aurora_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.aurora.id
  description       = "Allow all outbound traffic"
}

# Security group for bastion
resource "aws_security_group" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name_prefix = "${local.name_prefix}-bastion-"
  description = "Security group for bastion host (SSM managed)"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion-sg"
    Type = "bastion"
  })
}

# Optional SSH access (NOT recommended - use SSM instead)
resource "aws_security_group_rule" "bastion_ssh" {
  count = var.enable_bastion && length(var.admin_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.bastion[0].id
  description       = "SSH access (WARNING: Consider using SSM instead)"
}

# Allow all egress from bastion
resource "aws_security_group_rule" "bastion_egress" {
  count = var.enable_bastion ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion[0].id
  description       = "Allow all outbound traffic for updates and SSM"
}

# ===== AURORA DATABASE =====

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name_prefix = "${local.name_prefix}-aurora-"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for ${local.name_prefix} Aurora cluster"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-subnet-group"
  })
}

# DB Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "aurora" {
  name_prefix = "${local.name_prefix}-aurora-cluster-"
  family      = "aurora-mysql8.0"
  description = "Cluster parameter group for ${local.name_prefix}"

  # Enable slow query log
  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  # Enable performance schema
  parameter {
    name  = "performance_schema"
    value = var.performance_insights_enabled ? "1" : "0"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-cluster-params"
  })
}

# DB Parameter Group for instances
resource "aws_db_parameter_group" "aurora" {
  name_prefix = "${local.name_prefix}-aurora-instance-"
  family      = "aurora-mysql8.0"
  description = "Instance parameter group for ${local.name_prefix}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-instance-params"
  })
}

# IAM role for enhanced monitoring (if enabled)
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.enhanced_monitoring_interval > 0 ? 1 : 0

  name_prefix = "${local.name_prefix}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.enhanced_monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora_mysql" {
  cluster_identifier = "${local.name_prefix}-aurora"
  engine             = "aurora-mysql"
  engine_version     = var.aurora_engine_version
  engine_mode        = local.is_serverless ? "provisioned" : "provisioned"
  database_name      = var.db_name
  master_username    = var.db_master_username
  master_password    = random_password.db_master.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # Parameter groups
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  # Backup
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true

  # Security
  storage_encrypted = true
  # kms_key_id uses default AWS managed key when not specified
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery", "audit"]

  # Protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.env == "dev" ? true : false
  final_snapshot_identifier = var.env == "dev" ? null : "${local.name_prefix}-aurora-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Serverless v2 configuration
  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.is_serverless ? [1] : []
    content {
      min_capacity = var.serverless_min_acu
      max_capacity = var.serverless_max_acu
    }
  }

  tags = merge(local.common_tags, {
    Name            = "${local.name_prefix}-aurora-cluster"
    BackupRetention = tostring(var.backup_retention_period)
  })

  lifecycle {
    ignore_changes = [master_password]
  }
}

# Aurora Instance(s)
resource "aws_rds_cluster_instance" "aurora" {
  count = 2 # Writer + Reader

  identifier         = "${local.name_prefix}-aurora-${count.index == 0 ? "writer" : "reader-${count.index}"}"
  cluster_identifier = aws_rds_cluster.aurora_mysql.id

  engine         = aws_rds_cluster.aurora_mysql.engine
  engine_version = aws_rds_cluster.aurora_mysql.engine_version

  # Instance class based on serverless vs provisioned
  instance_class = local.is_serverless ? "db.serverless" : var.provisioned_instance_class

  db_parameter_group_name = aws_db_parameter_group.aurora.name

  # Performance insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  # Enhanced monitoring
  monitoring_interval = var.enhanced_monitoring_interval
  monitoring_role_arn = var.enhanced_monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  publicly_accessible = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-${count.index == 0 ? "writer" : "reader-${count.index}"}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}

# ===== BASTION HOST =====

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  count = var.enable_bastion ? 1 : 0

  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# IAM role for bastion (SSM managed)
resource "aws_iam_role" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name_prefix = "${local.name_prefix}-bastion-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion-role"
  })
}

# Attach SSM managed policy
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count = var.enable_bastion ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy for logging
resource "aws_iam_role_policy_attachment" "bastion_cloudwatch" {
  count = var.enable_bastion ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile for bastion
resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name_prefix = "${local.name_prefix}-bastion-"
  role        = aws_iam_role.bastion[0].name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion-profile"
  })
}

# Bastion EC2 instance
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023[0].id
  instance_type          = var.instance_type_bastion
  subnet_id              = element(var.public_subnet_ids, 0)
  vpc_security_group_ids = [aws_security_group.bastion[0].id]
  iam_instance_profile   = aws_iam_instance_profile.bastion[0].name

  associate_public_ip_address = true

  # Ensure IAM resources are created before instance
  depends_on = [
    aws_iam_role.bastion,
    aws_iam_instance_profile.bastion,
    aws_iam_role_policy_attachment.bastion_ssm,
    aws_iam_role_policy_attachment.bastion_cloudwatch
  ]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    # Update system
    dnf update -y

    # Install MySQL client
    dnf install -y mariadb105

    # Install CloudWatch agent
    wget https://amazoncloudwatch-agent.s3.amazonaws.com/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm

    # SSM agent is pre-installed on AL2023 - ensure it's properly configured
    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent

    # Wait for SSM agent to register (up to 5 minutes)
    for i in {1..30}; do
      if systemctl is-active --quiet amazon-ssm-agent; then
        echo "SSM agent is running"
        break
      fi
      echo "Waiting for SSM agent... attempt $i/30"
      sleep 10
    done

    # Force SSM agent registration
    /opt/amazon/ssm/bin/amazon-ssm-agent -register -clear -region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    systemctl restart amazon-ssm-agent

    # Set hostname
    hostnamectl set-hostname ${local.name_prefix}-bastion

    # Create mysql helper script
    cat > /usr/local/bin/connect-aurora.sh <<'SCRIPT'
    #!/bin/bash
    SECRET_ID="${aws_secretsmanager_secret.db_credentials.id}"
    REGION="$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')"

    # Fetch credentials from Secrets Manager
    CREDS=$(aws secretsmanager get-secret-value --secret-id $SECRET_ID --region $REGION --query SecretString --output text)

    # Parse credentials
    HOST=$(echo $CREDS | jq -r .host)
    PORT=$(echo $CREDS | jq -r .port)
    USER=$(echo $CREDS | jq -r .username)
    PASS=$(echo $CREDS | jq -r .password)
    DB=$(echo $CREDS | jq -r .dbname)

    echo "Connecting to Aurora cluster at $HOST..."
    mysql -h $HOST -P $PORT -u $USER -p$PASS $DB
    SCRIPT

    chmod +x /usr/local/bin/connect-aurora.sh

    echo "Bastion setup complete. Use SSM Session Manager to connect."
  EOF

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion"
    Type = "bastion-host"
    OS   = "AmazonLinux2023"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# Null resource to ensure IAM instance profile is properly attached
resource "null_resource" "bastion_iam_fix" {
  count = var.enable_bastion ? 1 : 0

  # Trigger when instance or profile changes
  triggers = {
    instance_id = aws_instance.bastion[0].id
    profile_arn = aws_iam_instance_profile.bastion[0].arn
  }

  # Ensure IAM instance profile is attached (backup in case inline attachment fails)
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      # Check if instance profile is attached, if not attach it
      $CURRENT_PROFILE = aws ec2 describe-instances --instance-ids ${aws_instance.bastion[0].id} --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>$null
      if ($LASTEXITCODE -ne 0) { $CURRENT_PROFILE = "None" }

      if ($CURRENT_PROFILE -eq "None" -or $CURRENT_PROFILE -eq "null" -or [string]::IsNullOrEmpty($CURRENT_PROFILE)) {
        Write-Host "Attaching IAM instance profile to bastion instance..."
        aws ec2 associate-iam-instance-profile --instance-id ${aws_instance.bastion[0].id} --iam-instance-profile Name=${aws_iam_instance_profile.bastion[0].name}

        # Wait for attachment
        Start-Sleep -Seconds 10

        # Verify attachment
        aws ec2 describe-instances --instance-ids ${aws_instance.bastion[0].id} --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn'
      } else {
        Write-Host "IAM instance profile already attached: $CURRENT_PROFILE"
      }
    EOT
  }

  depends_on = [
    aws_instance.bastion,
    aws_iam_instance_profile.bastion
  ]
}