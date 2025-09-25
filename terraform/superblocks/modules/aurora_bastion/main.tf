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

  # Configure Instance Metadata Service for SSM compatibility
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional" # Use "required" for IMDSv2 only, but SSM works better with "optional"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

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

    # Verify and install SSM agent if needed (should be pre-installed on AL2023)
    echo "========================================="
    echo "=== SSM AGENT SETUP STARTING ==="
    echo "========================================="
    echo "Timestamp: $(date)"

    # Get region from instance metadata
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "Instance ID: $INSTANCE_ID"
    echo "Instance region: $REGION"

    # Check if SSM agent is installed, if not install it
    echo "=== Checking SSM Agent Installation ==="
    if ! command -v amazon-ssm-agent &> /dev/null; then
        echo "[ERROR] SSM Agent not found, installing..."
        dnf install -y amazon-ssm-agent
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] SSM Agent installed successfully"
        else
            echo "[CRITICAL] Failed to install SSM Agent!"
        fi
    else
        echo "[OK] SSM Agent is already installed"
        amazon-ssm-agent --version 2>&1 || echo "[WARNING] Cannot get SSM agent version"
    fi

    # Ensure SSM agent package is up to date
    echo "=== Updating SSM Agent Package ==="
    dnf update -y amazon-ssm-agent
    echo "[INFO] SSM Agent update completed"

    # Test DNS resolution for SSM endpoints
    echo "=== Testing DNS Resolution for SSM Endpoints ==="
    for endpoint in ssm ssmmessages ec2messages; do
        echo "[TEST] Resolving $endpoint.$REGION.amazonaws.com..."
        nslookup $endpoint.$REGION.amazonaws.com
        if [ $? -eq 0 ]; then
            echo "[OK] $endpoint endpoint resolved successfully"
        else
            echo "[ERROR] Failed to resolve $endpoint endpoint!"
        fi
    done

    # Test connectivity to SSM endpoints
    echo "=== Testing HTTPS Connectivity to SSM Endpoints ==="
    for endpoint in ssm ssmmessages ec2messages; do
        echo "[TEST] Checking HTTPS connectivity to $endpoint.$REGION.amazonaws.com..."
        curl -I https://$endpoint.$REGION.amazonaws.com --connect-timeout 5 --max-time 10 2>&1
        if [ $? -eq 0 ]; then
            echo "[OK] $endpoint endpoint is reachable"
        else
            echo "[ERROR] Cannot reach $endpoint endpoint!"
        fi
    done

    # Configure SSM agent with correct region
    echo "=== Configuring SSM Agent ==="
    mkdir -p /etc/amazon/ssm
    echo "{\"Mds\":{\"CommandWorkersLimit\":5,\"StopTimeoutMillis\":20000,\"Endpoint\":\"\",\"CommandRetryLimit\":15},\"Ssm\":{\"Endpoint\":\"\",\"HealthFrequencyMinutes\":5,\"CustomInventoryEnabled\":false},\"Mgs\":{\"Region\":\"$REGION\",\"Endpoint\":\"\",\"StopTimeoutMillis\":20000,\"SessionWorkersLimit\":1000},\"Agent\":{\"Region\":\"$REGION\"}}" > /etc/amazon/ssm/amazon-ssm-agent.json
    echo "[INFO] SSM agent configuration written to /etc/amazon/ssm/amazon-ssm-agent.json"

    # Clear any existing registration
    echo "=== Clearing Previous SSM Registration ==="
    systemctl stop amazon-ssm-agent
    echo "[INFO] SSM agent stopped"
    rm -rf /var/lib/amazon/ssm/registration
    echo "[INFO] Previous registration data cleared"

    # Start SSM agent with fresh registration
    echo "=== Starting SSM Agent ==="
    systemctl enable amazon-ssm-agent
    echo "[INFO] SSM agent enabled for autostart"
    systemctl start amazon-ssm-agent
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] SSM agent start command executed"
    else
        echo "[ERROR] Failed to start SSM agent!"
        echo "[DEBUG] Checking systemd status..."
        systemctl status amazon-ssm-agent --no-pager
    fi

    # Create systemd drop-in to ensure SSM agent auto-restarts
    mkdir -p /etc/systemd/system/amazon-ssm-agent.service.d
    cat > /etc/systemd/system/amazon-ssm-agent.service.d/override.conf <<'SYSTEMD'
    [Service]
    Restart=always
    RestartSec=60
    StartLimitInterval=0
    StartLimitBurst=0

    [Unit]
    StartLimitIntervalSec=0
    SYSTEMD

    # Reload systemd to apply changes
    systemctl daemon-reload

    # Create a monitoring script that ensures SSM agent stays running
    cat > /usr/local/bin/monitor-ssm-agent.sh <<'MONITOR'
    #!/bin/bash
    # SSM Agent Monitor - Ensures SSM agent is always running

    while true; do
        if ! systemctl is-active --quiet amazon-ssm-agent; then
            echo "$(date): SSM Agent is not running, starting it..."

            # Clear any stale data
            rm -rf /var/lib/amazon/ssm/registration

            # Get region
            REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

            # Re-register and start
            /opt/amazon/ssm/bin/amazon-ssm-agent -register -clear -region $REGION 2>/dev/null
            systemctl restart amazon-ssm-agent

            # Wait for service to stabilize
            sleep 30

            if systemctl is-active --quiet amazon-ssm-agent; then
                echo "$(date): SSM Agent successfully restarted"
            else
                echo "$(date): SSM Agent failed to restart, will retry in 60 seconds"
            fi
        fi
        sleep 60
    done
    MONITOR

    chmod +x /usr/local/bin/monitor-ssm-agent.sh

    # Create systemd service for the monitor
    cat > /etc/systemd/system/ssm-monitor.service <<'SERVICE'
    [Unit]
    Description=SSM Agent Monitor
    After=network.target amazon-ssm-agent.service

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/monitor-ssm-agent.sh
    Restart=always
    StandardOutput=journal
    StandardError=journal

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # Create boot-time SSM diagnostic script
    cat > /usr/local/bin/ssm-boot-diagnostics.sh <<'BOOTDIAG'
    #!/bin/bash
    # SSM Boot Diagnostics - Runs on every boot/reboot

    LOG_FILE="/var/log/ssm-boot-diagnostics.log"
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    # Function to log with timestamp
    log_msg() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
    }

    # Start logging
    log_msg "========================================="
    log_msg "=== SSM BOOT DIAGNOSTICS STARTING ==="
    log_msg "========================================="
    log_msg "Instance: $INSTANCE_ID"
    log_msg "Region: $REGION"
    log_msg "Boot Time: $(uptime -s)"

    # Wait for network to be fully up
    sleep 10

    # Check SSM agent service status
    log_msg "=== SSM Agent Service Status ==="
    if systemctl is-active --quiet amazon-ssm-agent; then
        log_msg "[SUCCESS] SSM Agent service is ACTIVE"
        systemctl status amazon-ssm-agent --no-pager >> $LOG_FILE 2>&1
    else
        log_msg "[ERROR] SSM Agent service is NOT active"
        log_msg "Attempting to start SSM agent..."
        systemctl restart amazon-ssm-agent
        sleep 10
        if systemctl is-active --quiet amazon-ssm-agent; then
            log_msg "[RECOVERY] SSM Agent started successfully after retry"
        else
            log_msg "[CRITICAL] SSM Agent failed to start"
            journalctl -u amazon-ssm-agent -n 50 --no-pager >> $LOG_FILE 2>&1
        fi
    fi

    # Check network connectivity
    log_msg "=== Network Connectivity Test ==="
    if curl -s -o /dev/null -w "%{http_code}" https://ssm.$REGION.amazonaws.com --connect-timeout 5 | grep -q "403\|200"; then
        log_msg "[OK] Can reach SSM endpoint"
    else
        log_msg "[ERROR] Cannot reach SSM endpoint"
        # Try to diagnose network issue
        ip route show | grep default >> $LOG_FILE 2>&1
        nslookup ssm.$REGION.amazonaws.com >> $LOG_FILE 2>&1
    fi

    # Check IAM instance profile
    log_msg "=== IAM Instance Profile Check ==="
    PROFILE=$(curl -s http://169.254.169.254/latest/meta-data/iam/info 2>/dev/null)
    if [ $? -eq 0 ]; then
        log_msg "[OK] IAM instance profile is attached"
        echo "$PROFILE" >> $LOG_FILE
    else
        log_msg "[ERROR] No IAM instance profile attached"
    fi

    # Check SSM agent process
    log_msg "=== SSM Agent Process Check ==="
    if pgrep -f amazon-ssm-agent > /dev/null; then
        log_msg "[OK] SSM agent process is running"
        ps aux | grep ssm | grep -v grep >> $LOG_FILE
    else
        log_msg "[ERROR] No SSM agent process found"
    fi

    # Final status
    log_msg "=== SSM Registration Status ==="
    if [ -f /var/lib/amazon/ssm/registration ]; then
        log_msg "[INFO] Registration file exists"
    else
        log_msg "[WARNING] No registration file - agent may need to register"
    fi

    log_msg "=== SSM Boot Diagnostics Complete ==="
    echo "" >> $LOG_FILE

    # Also output to console for EC2 console output
    cat $LOG_FILE | tail -n 100
    BOOTDIAG

    chmod +x /usr/local/bin/ssm-boot-diagnostics.sh

    # Create systemd service to run diagnostics on boot
    cat > /etc/systemd/system/ssm-boot-diagnostics.service <<'BOOTSERVICE'
    [Unit]
    Description=SSM Boot Diagnostics
    After=network-online.target amazon-ssm-agent.service
    Wants=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/ssm-boot-diagnostics.sh
    RemainAfterExit=yes
    StandardOutput=journal+console
    StandardError=journal+console

    [Install]
    WantedBy=multi-user.target
    BOOTSERVICE

    # Enable and start the monitor service
    systemctl daemon-reload
    systemctl enable ssm-monitor.service
    systemctl enable ssm-boot-diagnostics.service
    systemctl start ssm-monitor.service

    # Run boot diagnostics now for initial setup
    echo "Running initial boot diagnostics..."
    /usr/local/bin/ssm-boot-diagnostics.sh

    # Wait for SSM agent to start
    sleep 30

    # Verify SSM agent is running
    echo "========================================="
    echo "=== SSM AGENT VERIFICATION ==="
    echo "========================================="

    echo "=== Checking SSM Agent Service Status ==="
    systemctl status amazon-ssm-agent --no-pager

    if systemctl is-active --quiet amazon-ssm-agent; then
        echo "[SUCCESS] ✓ SSM Agent service is ACTIVE"

        # Check if process is actually running
        echo "=== Verifying SSM Agent Process ==="
        SSM_PID=$(pgrep -f amazon-ssm-agent)
        if [ -n "$SSM_PID" ]; then
            echo "[OK] SSM Agent process running with PID: $SSM_PID"
            ps -fp $SSM_PID
        else
            echo "[WARNING] SSM Agent service is active but no process found!"
        fi
    else
        echo "[CRITICAL] ✗ SSM Agent service is NOT active"
        echo "[DEBUG] Checking systemd logs..."
        journalctl -u amazon-ssm-agent --no-pager -n 100
        echo "[DEBUG] Checking SSM agent log files..."
        if [ -f /var/log/amazon/ssm/amazon-ssm-agent.log ]; then
            echo "=== Last 50 lines of SSM agent log ==="
            tail -n 50 /var/log/amazon/ssm/amazon-ssm-agent.log
        fi
    fi

    # Log agent version and registration status
    echo "=== SSM Agent Version ==="
    amazon-ssm-agent --version 2>&1 || echo "[ERROR] Unable to get SSM agent version"

    # Check if agent can reach SSM service
    echo "=== Testing Final SSM Connectivity ==="
    curl -I https://ssm.$REGION.amazonaws.com --max-time 10 2>&1
    if [ $? -eq 0 ]; then
        echo "[OK] SSM endpoint is reachable"
    else
        echo "[ERROR] SSM endpoint is NOT reachable - this will prevent registration!"
    fi

    # Check SSM registration files
    echo "=== SSM Registration Status ==="
    if [ -f /var/lib/amazon/ssm/registration ]; then
        echo "[INFO] Registration file exists"
        ls -la /var/lib/amazon/ssm/
    else
        echo "[WARNING] No registration file found - agent may not be registered"
    fi

    # Final process check
    echo "=== Final SSM Process Check ==="
    ps aux | grep -i ssm | grep -v grep
    if [ $? -eq 0 ]; then
        echo "[OK] SSM processes are running"
    else
        echo "[CRITICAL] No SSM processes found running!"
    fi

    # Check network routes
    echo "=== Network Route Check ==="
    ip route show | grep default
    if [ $? -eq 0 ]; then
        echo "[OK] Default route exists"
    else
        echo "[ERROR] No default route - cannot reach internet!"
    fi

    # Add cron job as additional backup to ensure SSM agent runs
    echo "*/5 * * * * root systemctl is-active --quiet amazon-ssm-agent || systemctl restart amazon-ssm-agent" >> /etc/crontab

    # Add SSM agent check to rc.local for boot time
    cat >> /etc/rc.d/rc.local <<'RCLOCAL'
    #!/bin/bash
    # Ensure SSM agent starts on boot
    sleep 60
    systemctl is-active --quiet amazon-ssm-agent || systemctl restart amazon-ssm-agent
    RCLOCAL
    chmod +x /etc/rc.d/rc.local

    # Set hostname
    hostnamectl set-hostname ${local.name_prefix}-bastion

    # Create helper command to check SSM logs
    cat > /usr/local/bin/check-ssm.sh <<'CHECKSSM'
    #!/bin/bash
    echo "=== SSM Agent Status ==="
    systemctl status amazon-ssm-agent --no-pager

    echo -e "\n=== SSM Boot Diagnostics Log ==="
    if [ -f /var/log/ssm-boot-diagnostics.log ]; then
        tail -n 50 /var/log/ssm-boot-diagnostics.log
    else
        echo "No boot diagnostics log found"
    fi

    echo -e "\n=== SSM Agent Registration ==="
    aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --output table 2>/dev/null || echo "Cannot check SSM registration"
    CHECKSSM

    chmod +x /usr/local/bin/check-ssm.sh

    # Final message
    echo "=== Bastion Setup Complete ==="
    echo "SSM Agent Monitor: Enabled"
    echo "Auto-restart: Configured via systemd"
    echo "Boot diagnostics: Enabled (runs on every boot)"
    echo "Backup monitoring: Cron job every 5 minutes"
    echo "Boot check: rc.local configured"
    echo "Boot diagnostics log: /var/log/ssm-boot-diagnostics.log"
    echo "Helper command: /usr/local/bin/check-ssm.sh"

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