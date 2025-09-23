# --- database.tf ---
# Aurora MySQL Serverless v2 Database for Superblocks
# This file integrates the aurora_bastion module with your existing Superblocks deployment

# Deploy Aurora MySQL with Bastion
module "database" {
  source = "./modules/aurora_bastion"

  # Network Configuration - Reuse Superblocks networking
  vpc_id             = var.vpc_id
  private_subnet_ids = var.ecs_subnet_ids # Same private subnets as ECS tasks
  public_subnet_ids  = var.lb_subnet_ids  # Same public subnets as load balancer

  # Security - Allow access from Superblocks ECS tasks
  ecs_service_sg_id = module.superblocks_agent.ecs_security_group_id

  # Project Configuration
  project_name = "superblocks"
  env          = "dev"

  # Database Configuration
  db_name            = "wegdemodb"
  db_master_username = "wegdbadmin"

  # Aurora Serverless v2 Configuration (minimal for cost optimization)
  serverless_min_acu = 0.5 # Minimum capacity (0.5 ACU = ~$43/month)
  serverless_max_acu = 1.0 # Maximum capacity (scales as needed)

  # Use provisioned instances instead of serverless (optional)
  enable_provisioned_instead_of_serverless = false
  provisioned_instance_class               = "db.t3.medium"

  # Backup and Protection
  backup_retention_period = 7     # 7 days for dev, increase for production
  deletion_protection     = false # Set to true for production

  # Monitoring (optional, adds cost)
  performance_insights_enabled = false # Enable for production
  enhanced_monitoring_interval = 0     # Set to 60 for production

  # Bastion Host for Admin Access
  enable_bastion        = true
  instance_type_bastion = "t3.micro"

  # Optional: Allow SSH from specific IPs (not recommended, use SSM instead)
  admin_cidr_blocks = [] # e.g., ["203.0.113.0/32"] for your office IP

  # Additional Tags
  additional_tags = {
    Component = "Database"
    ManagedBy = "terraform"
  }
}

# ===== OUTPUTS =====

output "database_endpoints" {
  description = "Aurora database endpoints"
  value = {
    writer = module.database.aurora_writer_endpoint
    reader = module.database.aurora_reader_endpoint
  }
}

output "database_secret" {
  description = "Secrets Manager ARN containing database credentials"
  value       = module.database.db_secret_arn
  sensitive   = true
}

output "bastion_connect_command" {
  description = "Command to connect to bastion via SSM"
  value       = module.database.connection_info.ssm_connect_command
}

output "database_port_forward_command" {
  description = "Command to create port forward tunnel to database"
  value       = module.database.connection_info.ssm_tunnel_command
}

output "database_connection_guide" {
  description = "Complete guide for connecting to the database"
  value       = module.database.developer_guide
}

# ===== ENVIRONMENT VARIABLES FOR SUPERBLOCKS =====

# If you want Superblocks to connect to the database,
# add these environment variables to the superblocks module call in main.tf:

/*
module "superblocks_agent" {
  # ... existing configuration ...

  environment_variables = merge(
    var.environment_variables,
    {
      # Database connection environment variables
      DB_HOST        = module.database.aurora_writer_endpoint
      DB_PORT        = "3306"
      DB_NAME        = "wegdemodb"
      DB_SECRET_ARN  = module.database.db_secret_arn

      # Optional: Direct connection string (not recommended, use Secrets Manager)
      # DATABASE_URL = "mysql://user:pass@${module.database.aurora_writer_endpoint}:3306/wegdemodb"
    }
  )
}
*/