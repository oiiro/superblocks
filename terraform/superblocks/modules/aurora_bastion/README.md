# Aurora MySQL Serverless v2 with Bastion Host Module

Production-ready Terraform module for deploying Aurora MySQL Serverless v2 (or provisioned) with secure bastion access via AWS Systems Manager Session Manager.

## Features

- ✅ **Aurora MySQL 8.0** with Serverless v2 or Provisioned instances
- ✅ **Secrets Manager** for secure credential storage
- ✅ **Bastion Host** with SSM Session Manager (no SSH required)
- ✅ **Security Groups** with strict ingress rules
- ✅ **CloudWatch Logging** for audit, error, and slow queries
- ✅ **Performance Insights** and Enhanced Monitoring (optional)
- ✅ **Automated Backups** with configurable retention
- ✅ **Encryption at Rest** using AWS KMS
- ✅ **Multi-AZ** deployment across private subnets
- ✅ **DDL Scripts** for initial schema setup

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS VPC                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Public Subnets                    Private Subnets          │
│  ┌─────────────┐                   ┌─────────────────────┐ │
│  │   Bastion   │◄──────SSM─────────│                     │ │
│  │   (AL2023)  │                   │   Aurora MySQL      │ │
│  │             │──────3306─────────►│   Serverless v2    │ │
│  └─────────────┘                   │                     │ │
│                                    │  - Writer Instance  │ │
│  ┌─────────────┐                   │  - Reader Instance  │ │
│  │     ALB     │                   └─────────────────────┘ │
│  │             │                            ▲               │
│  └─────────────┘                            │               │
│         │                                   │               │
│         ▼                                   │               │
│  ┌─────────────────────────────────────────┘               │
│  │         ECS Service (Fargate)                           │
│  │         Security Group allows 3306 to Aurora            │
│  └──────────────────────────────────────────────────────── │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "database" {
  source = "./modules/aurora_bastion"

  # Network Configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  # Security
  ecs_service_sg_id = module.superblocks_agent.ecs_security_group_id

  # Project Tags
  project_name = "superblocks"
  env          = "dev"

  # Database Configuration
  db_name            = "wegdemodb"
  db_master_username = "wegdbadmin"

  # Serverless Configuration (minimal capacity)
  serverless_min_acu = 0.5
  serverless_max_acu = 1

  # Enable bastion for admin access
  enable_bastion = true
}
```

### Production Example

```hcl
module "database" {
  source = "./modules/aurora_bastion"

  # Network Configuration
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids

  # Security
  ecs_service_sg_id = var.ecs_service_sg_id

  # Project Tags
  project_name = "superblocks"
  env          = "prod"

  # Database Configuration
  db_name            = "wegdemodb"
  db_master_username = "wegdbadmin"

  # Use provisioned for production
  enable_provisioned_instead_of_serverless = true
  provisioned_instance_class                = "db.r6g.large"

  # Production Settings
  backup_retention_period      = 30
  deletion_protection          = true
  performance_insights_enabled = true
  enhanced_monitoring_interval = 60

  # Disable bastion in production (use VPN/Direct Connect)
  enable_bastion = false

  additional_tags = {
    CostCenter = "Engineering"
    Compliance = "PCI-DSS"
  }
}
```

### Integration with Superblocks

```hcl
# In your main.tf where Superblocks is deployed
module "superblocks_agent" {
  source = "../modules/superblocks_agent"
  # ... superblocks configuration ...
}

module "database" {
  source = "./modules/aurora_bastion"

  vpc_id             = var.vpc_id
  private_subnet_ids = var.ecs_subnet_ids  # Same as Superblocks ECS
  public_subnet_ids  = var.lb_subnet_ids   # Same as Superblocks ALB

  # Link to Superblocks ECS security group
  ecs_service_sg_id = module.superblocks_agent.ecs_security_group_id

  project_name = "superblocks"
  env          = var.env
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | VPC ID where resources will be created | string | - | yes |
| private_subnet_ids | List of private subnet IDs for Aurora | list(string) | - | yes |
| public_subnet_ids | List of public subnet IDs for bastion | list(string) | - | yes |
| ecs_service_sg_id | Security group ID of ECS service | string | - | yes |
| project_name | Project name for tagging | string | - | yes |
| env | Environment (dev/staging/prod) | string | - | yes |
| aurora_engine_version | Aurora MySQL engine version | string | "8.0.mysql_aurora.3.04.0" | no |
| serverless_min_acu | Minimum ACUs for Serverless v2 | number | 0.5 | no |
| serverless_max_acu | Maximum ACUs for Serverless v2 | number | 1 | no |
| enable_provisioned_instead_of_serverless | Use provisioned instances | bool | false | no |
| db_name | Database name | string | "wegdemodb" | no |
| db_master_username | Master username | string | "wegdbadmin" | no |
| backup_retention_period | Backup retention days | number | 1 | no |
| deletion_protection | Enable deletion protection | bool | false | no |
| performance_insights_enabled | Enable Performance Insights | bool | false | no |
| enhanced_monitoring_interval | Monitoring interval (0 to disable) | number | 0 | no |
| enable_bastion | Create bastion host | bool | true | no |
| instance_type_bastion | Bastion instance type | string | "t3.micro" | no |

## Outputs

| Name | Description |
|------|-------------|
| aurora_writer_endpoint | Writer endpoint for the Aurora cluster |
| aurora_reader_endpoint | Reader endpoint for the Aurora cluster |
| db_secret_arn | ARN of Secrets Manager secret with credentials |
| db_secret_name | Name of Secrets Manager secret |
| bastion_instance_id | Instance ID of bastion host |
| connection_info | Database connection URLs and commands |
| developer_guide | Complete guide for database access |

## Connecting to the Database

### 1. Via SSM Port Forwarding (Recommended)

```bash
# Start port forwarding
aws ssm start-session \
  --target $(terraform output -raw bastion_instance_id) \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters 'host="aurora-endpoint.region.rds.amazonaws.com",portNumber="3306",localPortNumber="3306"'

# Connect locally
mysql -h 127.0.0.1 -P 3306 -u wegdbadmin -p wegdemodb
```

### 2. Via SSM Session to Bastion

```bash
# Connect to bastion
aws ssm start-session --target $(terraform output -raw bastion_instance_id)

# Use the helper script
/usr/local/bin/connect-aurora.sh
```

### 3. From Application (ECS/Lambda)

```javascript
// Retrieve credentials from Secrets Manager
const AWS = require('aws-sdk');
const sm = new AWS.SecretsManager();

const secret = await sm.getSecretValue({
  SecretId: process.env.DB_SECRET_ARN
}).promise();

const credentials = JSON.parse(secret.SecretString);

// Connect using credentials
const mysql = require('mysql2');
const connection = mysql.createConnection({
  host: credentials.host,
  user: credentials.username,
  password: credentials.password,
  database: credentials.dbname,
  ssl: 'Amazon RDS'
});
```

## Applying Database Schema

After deployment, apply the initial schema:

```bash
# 1. Port forward to Aurora
aws ssm start-session \
  --target $(terraform output -raw bastion_instance_id) \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters 'host="'$(terraform output -json connection_info | jq -r .jdbc_writer_url | cut -d/ -f3 | cut -d: -f1)'",portNumber="3306",localPortNumber="3306"'

# 2. Get credentials
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw db_secret_name) \
  --query SecretString --output text | jq -r .password

# 3. Apply schema
mysql -h 127.0.0.1 -P 3306 -u wegdbadmin -p wegdemodb < modules/aurora_bastion/sql/001_init_schema.sql
```

## Database Schema

The included DDL creates:

- **users** - User accounts with authentication
- **accounts** - Financial accounts linked to users
- **transactions** - Transaction history with double-entry support
- **audit_logs** - Compliance audit trail
- **sessions** - Session management
- **Views** - Pre-built views for reporting
- **Stored Procedures** - Transaction processing logic
- **Indexes** - Optimized for common queries

## Security Considerations

1. **Network Isolation**: Database is in private subnets with no internet access
2. **Encryption**: Data encrypted at rest and in transit (SSL/TLS)
3. **Access Control**: Security group rules limit access to specific services
4. **Credential Management**: Passwords stored in AWS Secrets Manager
5. **Audit Logging**: CloudWatch logs capture all database activity
6. **Bastion Access**: SSM Session Manager eliminates SSH key management

## Cost Optimization

### Serverless v2 (Development)
- **Minimum**: 0.5 ACU = ~$43/month
- **Scales to**: 1 ACU = ~$87/month
- **Best for**: Development, testing, variable workloads

### Provisioned (Production)
- **db.t3.medium**: ~$60/month per instance
- **db.r6g.large**: ~$230/month per instance
- **Best for**: Predictable workloads, production

### Cost Saving Tips
1. Use Serverless v2 with 0.5 min ACU for dev/test
2. Enable auto-pause for development environments
3. Reduce backup retention in non-production
4. Use Reserved Instances for production

## Monitoring

### CloudWatch Metrics
- CPU utilization
- Database connections
- Read/Write latency
- Deadlocks and errors

### CloudWatch Logs
- Error logs
- General logs
- Slow query logs
- Audit logs

### Performance Insights (if enabled)
- Top SQL statements
- Wait events
- Database load

## Troubleshooting

### Cannot connect to database
```bash
# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check network ACLs
aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=subnet-xxxxx"

# Verify Aurora status
aws rds describe-db-clusters --db-cluster-identifier superblocks-dev-aurora
```

### SSM Session fails
```bash
# Check SSM agent status
aws ssm describe-instance-information --instance-information-filter-list key=InstanceIds,valueSet=i-xxxxx

# Check IAM role
aws iam get-role --role-name superblocks-dev-bastion-role
```

### Slow queries
```sql
-- Check slow query log
SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;

-- Check current processes
SHOW FULL PROCESSLIST;

-- Check table locks
SHOW OPEN TABLES WHERE In_use > 0;
```

## Migration and Upgrades

### Schema Migrations
```bash
# Track migrations in schema_migrations table
SELECT * FROM schema_migrations ORDER BY version;

# Apply new migrations
mysql -h aurora-endpoint -u wegdbadmin -p wegdemodb < sql/002_add_feature.sql
```

### Engine Upgrades
```bash
# Check available versions
aws rds describe-db-engine-versions --engine aurora-mysql --query 'DBEngineVersions[*].EngineVersion'

# Modify cluster
aws rds modify-db-cluster --db-cluster-identifier cluster-name --engine-version 8.0.mysql_aurora.3.05.0 --apply-immediately
```

## Production Hardening

For production deployments:

1. **Enable deletion protection**
   ```hcl
   deletion_protection = true
   ```

2. **Increase backup retention**
   ```hcl
   backup_retention_period = 30
   ```

3. **Enable monitoring**
   ```hcl
   performance_insights_enabled = true
   enhanced_monitoring_interval = 60
   ```

4. **Use larger instances**
   ```hcl
   enable_provisioned_instead_of_serverless = true
   provisioned_instance_class = "db.r6g.xlarge"
   ```

5. **Add read replicas**
   ```hcl
   # Modify main.tf to increase instance count
   count = 3  # 1 writer + 2 readers
   ```

6. **Enable audit logging**
   ```hcl
   enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
   ```

## License

This module is provided as-is for use with AWS infrastructure.

## Support

For issues or questions, please refer to the AWS Aurora MySQL documentation or contact your infrastructure team.