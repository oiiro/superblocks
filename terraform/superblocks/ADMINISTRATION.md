# Aurora MySQL Database Administration Guide

## Table of Contents
- [Database Connection Information](#database-connection-information)
- [User Management](#user-management)
- [Secrets Management](#secrets-management)
- [DNS Configuration](#dns-configuration)
- [Common Maintenance Operations](#common-maintenance-operations)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Backup and Recovery](#backup-and-recovery)

---

## Database Connection Information

### Production Aurora Cluster Details
- **Cluster Endpoint**: `superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com`
- **Port**: 3306
- **Database Name**: `wegdemodb`
- **Engine**: Aurora MySQL 8.0 (version 8.0.mysql_aurora.3.04.0)

### Connection Methods

#### Direct MySQL Connection
```bash
mysql -h superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com \
      -P 3306 \
      -u wegdbadmin \
      -p \
      wegdemodb
```

#### MySQL URI Format
```
mysql://wegdbadmin:<password>@superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com:3306/wegdemodb
```

#### Via Bastion Host
```bash
# 1. Connect to bastion using SSM Session Manager
aws ssm start-session --target <bastion-instance-id> --region us-east-1

# 2. From bastion, connect to database
mysql -h superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com \
      -u wegdbadmin -p wegdemodb
```

---

## User Management

### Creating Application Users (Non-Admin)

#### Standard Application User for Superblocks
This creates a user with full data manipulation privileges but no administrative capabilities:

```sql
-- Connect as admin first
mysql -h superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com \
      -u wegdbadmin -p wegdemodb

-- Create application user
CREATE USER 'superblocks_app'@'%' IDENTIFIED BY 'YourSecurePassword123!';

-- Grant application-level privileges on wegdemodb database
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES
ON wegdemodb.* TO 'superblocks_app'@'%';

-- Grant additional operational privileges
GRANT CREATE TEMPORARY TABLES, EXECUTE, LOCK TABLES, EVENT, TRIGGER
ON wegdemodb.* TO 'superblocks_app'@'%';

-- Grant ability to view routines (stored procedures/functions)
GRANT CREATE ROUTINE, ALTER ROUTINE ON wegdemodb.* TO 'superblocks_app'@'%';

-- Apply privileges
FLUSH PRIVILEGES;

-- Verify user creation
SELECT User, Host FROM mysql.user WHERE User = 'superblocks_app';

-- Show granted privileges
SHOW GRANTS FOR 'superblocks_app'@'%';
```

#### Read-Only User for Reporting
```sql
-- Create read-only user
CREATE USER 'superblocks_readonly'@'%' IDENTIFIED BY 'ReadOnlyPassword123!';

-- Grant SELECT only privilege
GRANT SELECT ON wegdemodb.* TO 'superblocks_readonly'@'%';

-- Grant ability to view routine definitions
GRANT SHOW VIEW ON wegdemodb.* TO 'superblocks_readonly'@'%';

-- Apply privileges
FLUSH PRIVILEGES;

-- Verify grants
SHOW GRANTS FOR 'superblocks_readonly'@'%';
```

#### Developer User with Limited Admin
```sql
-- Create developer user
CREATE USER 'superblocks_dev'@'%' IDENTIFIED BY 'DevPassword123!';

-- Grant full privileges on wegdemodb except GRANT OPTION
GRANT ALL PRIVILEGES ON wegdemodb.* TO 'superblocks_dev'@'%';

-- Apply privileges
FLUSH PRIVILEGES;

-- Verify grants
SHOW GRANTS FOR 'superblocks_dev'@'%';
```

### Managing Existing Users

#### List All Users
```sql
-- Show all users
SELECT User, Host, authentication_string FROM mysql.user;

-- Show users with specific database access
SELECT DISTINCT User, Host
FROM mysql.db
WHERE Db = 'wegdemodb';
```

#### Modify User Privileges
```sql
-- Add privilege to existing user
GRANT CREATE VIEW ON wegdemodb.* TO 'superblocks_app'@'%';

-- Remove specific privilege
REVOKE DROP ON wegdemodb.* FROM 'superblocks_app'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

#### Change User Password
```sql
-- Using ALTER USER (Aurora MySQL 8.0 compatible)
ALTER USER 'superblocks_app'@'%' IDENTIFIED BY 'NewSecurePassword123!';

-- Alternative method
SET PASSWORD FOR 'superblocks_app'@'%' = 'NewSecurePassword123!';

FLUSH PRIVILEGES;
```

#### Delete User
```sql
-- Remove user and all privileges
DROP USER IF EXISTS 'superblocks_app'@'%';

-- Verify deletion
SELECT User, Host FROM mysql.user WHERE User = 'superblocks_app';
```

---

## Secrets Management

### AWS Secrets Manager Operations

#### Create New Secret for Application User
```bash
# Create secret with proper JSON structure
aws secretsmanager create-secret \
  --name "superblocks-dev-aurora-app-user" \
  --description "Application user credentials for Superblocks Aurora cluster" \
  --secret-string '{
    "username": "superblocks_app",
    "password": "YourSecurePassword123!",
    "engine": "mysql",
    "host": "superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com",
    "port": 3306,
    "dbname": "wegdemodb"
  }' \
  --region us-east-1 \
  --tags '[
    {"Key": "Project", "Value": "Superblocks"},
    {"Key": "Environment", "Value": "dev"},
    {"Key": "Type", "Value": "database-credentials"}
  ]'
```

#### Update Existing Secret
```bash
# Get current secret name
SECRET_NAME=$(aws secretsmanager list-secrets \
  --query 'SecretList[?contains(Name,`aurora`) && contains(Name,`app`)].Name' \
  --output text --region us-east-1)

# Update password only (preserving other fields)
aws secretsmanager update-secret \
  --secret-id "$SECRET_NAME" \
  --secret-string '{
    "username": "superblocks_app",
    "password": "NewSecurePassword123!",
    "engine": "mysql",
    "host": "superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com",
    "port": 3306,
    "dbname": "wegdemodb"
  }' \
  --region us-east-1
```

#### Retrieve Secret Values
```bash
# Get secret value
aws secretsmanager get-secret-value \
  --secret-id "superblocks-dev-aurora-app-user" \
  --region us-east-1 \
  --query 'SecretString' \
  --output text | jq .

# Extract specific values
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "superblocks-dev-aurora-app-user" \
  --region us-east-1 \
  --query 'SecretString' \
  --output text | jq -r '.password')
```

#### Rotate Secrets
```bash
# Enable automatic rotation (requires Lambda function)
aws secretsmanager rotate-secret \
  --secret-id "superblocks-dev-aurora-app-user" \
  --rotation-lambda-arn "arn:aws:lambda:us-east-1:ACCOUNT:function:SecretsManagerRotation" \
  --rotation-rules AutomaticallyAfterDays=30 \
  --region us-east-1

# Trigger immediate rotation
aws secretsmanager rotate-secret \
  --secret-id "superblocks-dev-aurora-app-user" \
  --rotate-immediately \
  --region us-east-1
```

---

## DNS Configuration

### Creating CNAME Records for Easy Access

#### Route53 Configuration (AWS)
```bash
# Create CNAME record in Route53
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "superblocksdevdb.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{
          "Value": "superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com"
        }]
      }
    }]
  }'
```

#### Alternative DNS Providers

**CloudFlare DNS:**
```bash
# Using CloudFlare API
curl -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "X-Auth-Email: ${CF_EMAIL}" \
  -H "X-Auth-Key: ${CF_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "superblocksdevdb",
    "content": "superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com",
    "ttl": 300,
    "proxied": false
  }'
```

**BIND DNS Zone File Entry:**
```bind
; CNAME record for Aurora cluster
superblocksdevdb    IN    CNAME    superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com.
```

#### Multiple Environment CNAMEs
```bash
# Development
superblocksdevdb.example.com    → superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com

# Staging
superblocksqadb.example.com     → superblocks-qa-aurora.cluster-wegdbqacluster.us-east-1.rds.amazonaws.com

# Production
superblocksproddb.example.com   → superblocks-prod-aurora.cluster-wegdbprodcluster.us-east-1.rds.amazonaws.com
```

### Testing DNS Resolution
```bash
# Test CNAME resolution
nslookup superblocksdevdb.example.com
dig superblocksdevdb.example.com CNAME

# Test database connection with CNAME
mysql -h superblocksdevdb.example.com -u superblocks_app -p wegdemodb
```

---

## Common Maintenance Operations

### Database Performance Queries

#### Check Current Connections
```sql
-- Show all active connections
SELECT
    ID,
    USER,
    HOST,
    DB,
    COMMAND,
    TIME,
    STATE,
    LEFT(INFO, 100) AS QUERY_PREVIEW
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
ORDER BY TIME DESC;

-- Count connections by user
SELECT USER, COUNT(*) as connection_count
FROM information_schema.PROCESSLIST
GROUP BY USER
ORDER BY connection_count DESC;
```

#### Find Long Running Queries
```sql
-- Queries running longer than 60 seconds
SELECT
    ID,
    USER,
    TIME,
    STATE,
    LEFT(INFO, 200) AS QUERY
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
  AND TIME > 60
ORDER BY TIME DESC;

-- Kill long running query (use ID from above)
KILL QUERY <process_id>;
```

#### Table Size and Statistics
```sql
-- Database size
SELECT
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'wegdemodb'
GROUP BY table_schema;

-- Table sizes in database
SELECT
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)',
    table_rows AS 'Row Count'
FROM information_schema.tables
WHERE table_schema = 'wegdemodb'
ORDER BY (data_length + index_length) DESC
LIMIT 20;

-- Index usage statistics
SELECT
    table_name,
    index_name,
    ROUND(((index_length) / 1024 / 1024), 2) AS 'Index Size (MB)'
FROM information_schema.statistics
WHERE table_schema = 'wegdemodb'
GROUP BY table_name, index_name
ORDER BY index_length DESC
LIMIT 20;
```

### Table Maintenance

#### Optimize Tables (Aurora MySQL Compatible)
```sql
-- Analyze table statistics
ANALYZE TABLE wegdemodb.your_table_name;

-- Check table for errors
CHECK TABLE wegdemodb.your_table_name;

-- Optimize table (be careful with large tables)
OPTIMIZE TABLE wegdemodb.your_table_name;
```

#### Find and Fix Fragmented Tables
```sql
-- Find fragmented tables
SELECT
    table_name,
    data_free / 1024 / 1024 AS fragmentation_mb
FROM information_schema.tables
WHERE table_schema = 'wegdemodb'
  AND data_free > 100 * 1024 * 1024  -- Tables with >100MB fragmentation
ORDER BY data_free DESC;
```

### Lock Management

#### View Current Locks
```sql
-- Check for lock waits (Aurora MySQL 8.0)
SELECT
    r.trx_id AS waiting_trx_id,
    r.trx_mysql_thread_id AS waiting_thread,
    r.trx_query AS waiting_query,
    b.trx_id AS blocking_trx_id,
    b.trx_mysql_thread_id AS blocking_thread,
    b.trx_query AS blocking_query
FROM information_schema.innodb_lock_waits w
INNER JOIN information_schema.innodb_trx b
    ON b.trx_id = w.blocking_trx_id
INNER JOIN information_schema.innodb_trx r
    ON r.trx_id = w.requesting_trx_id;

-- Show all InnoDB locks
SELECT * FROM information_schema.innodb_locks;
```

### Slow Query Analysis

#### Enable Slow Query Log
```sql
-- Check current settings
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- These are typically set in parameter groups for Aurora
-- But can be checked with:
SELECT @@slow_query_log;
SELECT @@long_query_time;
```

#### Query Performance Schema (Aurora MySQL 8.0)
```sql
-- Top 10 slowest queries
SELECT
    DIGEST_TEXT,
    COUNT_STAR,
    AVG_TIMER_WAIT/1000000000 AS avg_latency_ms,
    SUM_TIMER_WAIT/1000000000 AS total_latency_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;
```

---

## Monitoring and Troubleshooting

### CloudWatch Metrics

#### Key Metrics to Monitor
```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=superblocks-dev-aurora \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Average \
  --region us-east-1

# Database Connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=superblocks-dev-aurora \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Maximum \
  --region us-east-1
```

### Connection Troubleshooting

#### Test Basic Connectivity
```bash
# From bastion or application server
# Test DNS resolution
nslookup superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com

# Test port connectivity
nc -zv superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com 3306

# Test with telnet
telnet superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com 3306

# MySQL connection test
mysql -h superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com \
      -u superblocks_app \
      -p \
      -e "SELECT 'Connection successful' as status, NOW() as timestamp;"
```

#### Security Group Validation
```bash
# Get cluster security groups
aws rds describe-db-clusters \
  --db-cluster-identifier superblocks-dev-aurora \
  --query 'DBClusters[0].VpcSecurityGroups[*].VpcSecurityGroupId' \
  --region us-east-1

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --query 'SecurityGroups[*].IpPermissions[?FromPort==`3306`]' \
  --region us-east-1
```

### Performance Troubleshooting

#### Identify Table Without Primary Keys
```sql
-- Tables without primary keys (bad for Aurora performance)
SELECT
    t.table_schema,
    t.table_name
FROM information_schema.tables t
LEFT JOIN information_schema.key_column_usage k
    ON t.table_schema = k.table_schema
    AND t.table_name = k.table_name
    AND k.constraint_name = 'PRIMARY'
WHERE t.table_schema = 'wegdemodb'
    AND t.table_type = 'BASE TABLE'
    AND k.constraint_name IS NULL;
```

#### Find Duplicate Indexes
```sql
-- Find potentially duplicate indexes
SELECT
    table_name,
    GROUP_CONCAT(index_name) as indexes,
    GROUP_CONCAT(column_name) as columns
FROM information_schema.statistics
WHERE table_schema = 'wegdemodb'
GROUP BY table_name, column_name
HAVING COUNT(DISTINCT index_name) > 1;
```

---

## Backup and Recovery

### Manual Snapshots

#### Create Manual Snapshot
```bash
# Create cluster snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier superblocks-dev-aurora-manual-$(date +%Y%m%d-%H%M%S) \
  --db-cluster-identifier superblocks-dev-aurora \
  --region us-east-1 \
  --tags '[
    {"Key": "Type", "Value": "Manual"},
    {"Key": "Reason", "Value": "Pre-deployment backup"}
  ]'
```

#### List Snapshots
```bash
# List all snapshots for cluster
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier superblocks-dev-aurora \
  --query 'DBClusterSnapshots[*].[DBClusterSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table \
  --region us-east-1
```

#### Restore from Snapshot
```bash
# Restore cluster from snapshot
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier superblocks-dev-aurora-restored \
  --snapshot-identifier <snapshot-id> \
  --engine aurora-mysql \
  --engine-version 8.0.mysql_aurora.3.04.0 \
  --region us-east-1
```

### Data Export/Import

#### Export Database
```bash
# From bastion host
mysqldump -h superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com \
          -u wegdbadmin \
          -p \
          --single-transaction \
          --routines \
          --triggers \
          --events \
          wegdemodb > wegdemodb_backup_$(date +%Y%m%d).sql

# Compress backup
gzip wegdemodb_backup_$(date +%Y%m%d).sql

# Upload to S3
aws s3 cp wegdemodb_backup_$(date +%Y%m%d).sql.gz \
          s3://your-backup-bucket/aurora-backups/ \
          --region us-east-1
```

#### Import Database
```bash
# Download from S3
aws s3 cp s3://your-backup-bucket/aurora-backups/wegdemodb_backup_20240101.sql.gz . \
          --region us-east-1

# Decompress
gunzip wegdemodb_backup_20240101.sql.gz

# Import to database
mysql -h superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com \
      -u wegdbadmin \
      -p \
      wegdemodb < wegdemodb_backup_20240101.sql
```

---

## Aurora MySQL Specific Features

### Aurora-Specific Functions
```sql
-- Aurora version information
SELECT AURORA_VERSION();

-- Check if using parallel query
SHOW VARIABLES LIKE 'aurora_parallel_query';

-- Enable parallel query for session
SET SESSION aurora_parallel_query = ON;

-- Check reader endpoint usage
SELECT @@aurora_server_id, @@hostname;
```

### Aurora Fast Clone
```bash
# Create fast database clone
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier superblocks-dev-aurora \
  --db-cluster-identifier superblocks-dev-aurora-clone \
  --restore-type copy-on-write \
  --use-latest-restorable-time \
  --region us-east-1
```

---

## Security Best Practices

### Password Policy Recommendations
- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, and special characters
- Avoid dictionary words
- Rotate every 90 days
- Never store in code repositories

### Connection Security
```bash
# Always use SSL/TLS for connections
mysql -h superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com \
      --ssl-mode=REQUIRED \
      -u superblocks_app \
      -p \
      wegdemodb

# Verify SSL connection in MySQL
SHOW STATUS LIKE 'Ssl_cipher';
```

### Audit Logging
```sql
-- Check if audit logging is enabled
SHOW VARIABLES LIKE 'server_audit%';

-- These are typically configured in the cluster parameter group
```

---

## Automation Scripts

### Daily Health Check Script
```bash
#!/bin/bash
# save as daily_health_check.sh

DB_HOST="superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com"
DB_USER="superblocks_app"
DB_PASS="YourSecurePassword123!"
DB_NAME="wegdemodb"

echo "=== Aurora MySQL Daily Health Check ==="
echo "Date: $(date)"
echo "Cluster: $DB_HOST"
echo ""

# Check connectivity
echo "1. Testing Connectivity..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 'OK' as status;" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ Connection successful"
else
    echo "   ✗ Connection failed"
    exit 1
fi

# Check database size
echo "2. Database Size:"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Total Size (MB)'
FROM information_schema.tables
WHERE table_schema = '$DB_NAME';" 2>/dev/null

# Check active connections
echo "3. Active Connections:"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "
SELECT COUNT(*) as 'Total Connections'
FROM information_schema.PROCESSLIST;" 2>/dev/null

# Check for locks
echo "4. Lock Status:"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "
SELECT COUNT(*) as 'Active Locks'
FROM information_schema.innodb_locks;" 2>/dev/null

echo ""
echo "=== Health Check Complete ==="
```

### Connection Pool Test
```python
#!/usr/bin/env python3
# save as test_connection_pool.py

import mysql.connector
from mysql.connector import pooling
import time

# Database configuration
config = {
    'user': 'superblocks_app',
    'password': 'YourSecurePassword123!',
    'host': 'superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com',
    'database': 'wegdemodb',
    'raise_on_warnings': True
}

# Create connection pool
try:
    pool = mysql.connector.pooling.MySQLConnectionPool(
        pool_name="superblocks_pool",
        pool_size=5,
        **config
    )

    print("Connection pool created successfully")

    # Test connections
    for i in range(10):
        conn = pool.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT CONNECTION_ID()")
        conn_id = cursor.fetchone()[0]
        print(f"Test {i+1}: Connected with ID {conn_id}")
        cursor.close()
        conn.close()
        time.sleep(0.5)

    print("All connection tests passed")

except mysql.connector.Error as err:
    print(f"Error: {err}")
```

---

## Terraform Integration

### Reference in Terraform Variables
```hcl
# terraform.tfvars
database_config = {
  host     = "superblocksdevdb.example.com"  # Using CNAME
  port     = 3306
  database = "wegdemodb"
  username = "superblocks_app"
}

# For secrets reference
database_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:superblocks-dev-aurora-app-user-XXXXXX"
```

### Output Database Endpoint
```hcl
output "database_endpoint" {
  value = {
    cluster_endpoint = "superblocks-dev-aurora.cluster-wegdbdevcluster.us-east-1.rds.amazonaws.com"
    cname_endpoint   = "superblocksdevdb.example.com"
    port             = 3306
    database         = "wegdemodb"
  }
  description = "Aurora MySQL database connection details"
}
```

---

## Support and Documentation

### AWS Documentation
- [Aurora MySQL Reference](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraMySQL.html)
- [Aurora MySQL 8.0 Compatibility](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraMySQL.Updates.ServerUpdates.html)

### Contact Information
- **Database Administrator**: DBA Team
- **Infrastructure Team**: DevOps Team
- **Emergency Contact**: On-call engineer via PagerDuty

### Version History
- **v1.0.0** - Initial documentation
- **Last Updated**: 2024-01-01
- **Aurora Version**: 8.0.mysql_aurora.3.04.0