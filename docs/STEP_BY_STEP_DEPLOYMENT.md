# Step-by-Step Superblocks Private Agent Deployment

## Complete Sequential Deployment Guide

This guide provides a detailed, step-by-step process for deploying Superblocks private agent with domain `agent.superblocks.oiiro.com`.

## Pre-Deployment Checklist

- [ ] New AWS account created for Superblocks
- [ ] AWS CLI configured with appropriate permissions
- [ ] Terraform >= 1.5.0 installed
- [ ] Access to OIIRO shared services account for DNS delegation
- [ ] Superblocks agent key obtained from dashboard

## Step 1: VPC Infrastructure Deployment

### 1.1 Initialize VPC Module
```bash
cd /Users/rohitiyer/oiiro/superblocks/terraform/vpc
terraform init
```

### 1.2 Plan VPC Deployment
```bash
terraform plan -var-file="../environments/superblocks.tfvars" -out=vpc.tfplan
```

**Expected Resources to be Created:**
- 1 VPC with CIDR 10.100.0.0/16
- 2 Public subnets (10.100.1.0/24, 10.100.2.0/24)
- 2 Private subnets (10.100.10.0/24, 10.100.20.0/24)
- 1 Internet Gateway
- 2 NAT Gateways with Elastic IPs
- 4 Route tables
- 2 Security groups (ALB and ECS)
- 1 VPC Flow Logs configuration

### 1.3 Apply VPC Infrastructure
```bash
terraform apply vpc.tfplan
```

### 1.4 Verify VPC Creation
```bash
# Get VPC ID from outputs
VPC_ID=$(terraform output -raw vpc_id)
echo "VPC Created: $VPC_ID"

# Verify subnets
terraform output public_subnet_ids
terraform output private_subnet_ids
```

**Expected Outputs:**
```
vpc_id = "vpc-0123456789abcdef0"
public_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0987654321fedcba0"]
private_subnet_ids = ["subnet-0246813579bdf024", "subnet-0864209753acf086"]
```

---

## Step 2: DNS Hosted Zone Creation

### 2.1 Create Subdomain Hosted Zone
```bash
# Create hosted zone for superblocks.oiiro.com
aws route53 create-hosted-zone \
  --name superblocks.oiiro.com \
  --caller-reference "superblocks-$(date +%s)" \
  --query 'HostedZone.Id' \
  --output text
```

### 2.2 Extract Name Servers
```bash
# Get the hosted zone ID (from previous command or list-hosted-zones)
HOSTED_ZONE_ID="Z1234567890ABC"

# Extract NS records for delegation
aws route53 get-hosted-zone \
  --id $HOSTED_ZONE_ID \
  --query 'DelegationSet.NameServers' \
  --output table
```

**Sample Output:**
```
---------------------------------
|        NameServers            |
+-------------------------------+
|  ns-123.awsdns-12.com         |
|  ns-456.awsdns-34.net         |
|  ns-789.awsdns-56.org         |
|  ns-012.awsdns-78.co.uk       |
+-------------------------------+
```

---

## Step 3: Cross-Account DNS Delegation

### 3.1 Switch to Shared Services Account
```bash
# Use OIIRO shared services AWS profile
export AWS_PROFILE=oiiro-shared-services
# or
aws configure --profile oiiro-shared-services
```

### 3.2 Find Parent Hosted Zone
```bash
# Find oiiro.com hosted zone ID
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`oiiro.com.`].Id' \
  --output text
```

### 3.3 Create NS Delegation Record
```bash
# Replace with actual values from Steps 2.2 and 3.2
PARENT_ZONE_ID="Z0987654321XYZ"

aws route53 change-resource-record-sets \
  --hosted-zone-id $PARENT_ZONE_ID \
  --change-batch '{
    "Comment": "Delegate superblocks.oiiro.com to Superblocks account",
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "superblocks.oiiro.com",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "ns-123.awsdns-12.com"},
          {"Value": "ns-456.awsdns-34.net"},
          {"Value": "ns-789.awsdns-56.org"},
          {"Value": "ns-012.awsdns-78.co.uk"}
        ]
      }
    }]
  }'
```

### 3.4 Verify DNS Delegation
```bash
# Wait 2-3 minutes, then test
dig NS superblocks.oiiro.com

# Should return the NS records from Step 2.2
```

### 3.5 Switch Back to Superblocks Account
```bash
export AWS_PROFILE=superblocks
# or
aws configure --profile superblocks
```

---

## Step 4: Application Load Balancer Deployment

### 4.1 Initialize Superblocks Module
```bash
cd /Users/rohitiyer/oiiro/superblocks/terraform/superblocks
terraform init
```

### 4.2 Plan Superblocks Deployment
```bash
terraform plan -var-file="../environments/superblocks.tfvars" -out=superblocks.tfplan
```

**Expected Resources to be Created:**
- 1 Application Load Balancer (internal)
- 1 Target Group
- 1 HTTPS Listener
- 1 ACM Certificate for agent.superblocks.oiiro.com
- DNS validation records

### 4.3 Apply Load Balancer First (Partial)
```bash
# Apply only ALB and certificate resources first
terraform apply -target=module.superblocks.aws_lb.main superblocks.tfplan
```

### 4.4 Verify Certificate Validation
```bash
# Check certificate status
aws acm list-certificates \
  --certificate-statuses ISSUED \
  --query 'CertificateSummaryList[?DomainName==`agent.superblocks.oiiro.com`]'
```

**Wait for certificate to be ISSUED before proceeding.**

---

## Step 5: ECS Cluster Deployment

### 5.1 Apply ECS Resources
```bash
# Continue with ECS cluster and service
terraform apply superblocks.tfplan
```

**Expected Resources to be Created:**
- 1 ECS Cluster
- 1 ECS Service
- 1 ECS Task Definition
- 2 IAM Roles (task execution and task role)
- 1 CloudWatch Log Group
- 1 Application Auto Scaling Target
- 1 Application Auto Scaling Policy

### 5.2 Verify ECS Deployment
```bash
# Check cluster status
aws ecs describe-clusters --clusters superblocks-cluster

# Check service status
aws ecs describe-services \
  --cluster superblocks-cluster \
  --services superblocks-agent \
  --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}'
```

**Expected Output:**
```json
{
    "Status": "ACTIVE",
    "RunningCount": 1,
    "DesiredCount": 1
}
```

---

## Step 6: RDS Database Deployment (Optional)

### 6.1 Update Configuration for RDS
```bash
# Edit superblocks.tfvars to enable RDS
vi /Users/rohitiyer/oiiro/superblocks/terraform/environments/superblocks.tfvars

# Add RDS configuration
enable_rds = true
db_instance_class = "db.t3.micro"
db_name = "superblocks"
db_username = "superblocks_admin"
```

### 6.2 Apply RDS Resources
```bash
terraform plan -var-file="../environments/superblocks.tfvars" -out=rds.tfplan
terraform apply rds.tfplan
```

**Expected Resources:**
- 1 RDS Subnet Group
- 1 RDS PostgreSQL Instance
- 1 RDS Security Group
- 1 Secrets Manager Secret (for DB credentials)

---

## Step 7: Secrets Manager Configuration

### 7.1 Store Superblocks Agent Key
```bash
# Create secret for agent key
aws secretsmanager create-secret \
  --name "superblocks/agent-key" \
  --description "Superblocks Agent Key" \
  --secret-string "your-actual-agent-key-here"
```

### 7.2 Update ECS Task Definition
The Terraform configuration should automatically reference the secret:
```hcl
environment = {
  SUPERBLOCKS_AGENT_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:superblocks/agent-key"
}
```

---

## Step 8: Monitoring Setup

### 8.1 CloudWatch Log Groups
```bash
# Verify log group creation
aws logs describe-log-groups \
  --log-group-name-prefix "/ecs/superblocks"
```

### 8.2 CloudWatch Alarms
```bash
# Check alarm status
aws cloudwatch describe-alarms \
  --alarm-name-prefix "superblocks" \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}'
```

---

## Step 9: Final Verification

### 9.1 DNS Resolution Test
```bash
# Test DNS resolution
nslookup agent.superblocks.oiiro.com

# Should resolve to ALB private IP addresses
```

### 9.2 HTTPS Certificate Test
```bash
# Test HTTPS connectivity (from within VPC or VPN)
curl -I https://agent.superblocks.oiiro.com

# Should return HTTP/1.1 200 OK with valid certificate
```

### 9.3 ECS Service Health Check
```bash
# Check ECS service health
aws ecs describe-services \
  --cluster superblocks-cluster \
  --services superblocks-agent \
  --query 'services[0].events[0:3]'
```

### 9.4 ALB Target Health
```bash
# Get target group ARN
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
  --names superblocks-agent-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN
```

**Expected healthy targets:**
```json
{
    "TargetHealthDescriptions": [
        {
            "Target": {
                "Id": "10.100.10.123",
                "Port": 8080
            },
            "HealthCheckPort": "8080",
            "TargetHealth": {
                "State": "healthy"
            }
        }
    ]
}
```

---

## Step 10: Access Configuration

### 10.1 VPN/Bastion Setup (For Private ALB Access)
Since the ALB is internal, you'll need:

**Option A: VPN Connection**
```bash
# Set up VPN connection to VPC
# Configure client to access 10.100.0.0/16 network
```

**Option B: Bastion Host**
```bash
# Deploy bastion host in public subnet
# SSH tunnel through bastion to access private ALB
```

### 10.2 Test Application Access
```bash
# From within VPC network
curl https://agent.superblocks.oiiro.com/health

# Should return Superblocks agent health status
```

---

## Troubleshooting Guide

### Common Issues

#### 1. DNS Delegation Not Working
```bash
# Check delegation path
dig +trace agent.superblocks.oiiro.com

# Verify NS records in parent zone
dig NS superblocks.oiiro.com @8.8.8.8
```

#### 2. Certificate Validation Timeout
```bash
# Check DNS validation records
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query 'ResourceRecordSets[?Type==`CNAME`]'
```

#### 3. ECS Tasks Not Starting
```bash
# Check CloudWatch logs
aws logs tail /ecs/superblocks-agent --follow

# Check task definition
aws ecs describe-task-definition --task-definition superblocks-agent
```

#### 4. Load Balancer Health Check Failures
```bash
# Check security groups
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxxx \
  --query 'SecurityGroups[0].IpPermissions'

# Check target group health
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
```

### Recovery Commands

#### Restart ECS Service
```bash
aws ecs update-service \
  --cluster superblocks-cluster \
  --service superblocks-agent \
  --force-new-deployment
```

#### Check Task Events
```bash
aws ecs describe-services \
  --cluster superblocks-cluster \
  --services superblocks-agent \
  --query 'services[0].events[0:5]'
```

---

## Post-Deployment Tasks

1. **Configure Superblocks Dashboard**
   - Add agent.superblocks.oiiro.com to Superblocks console
   - Verify agent connectivity

2. **Security Hardening**
   - Review security group rules
   - Enable VPC Flow Logs analysis
   - Set up CloudWatch alerts

3. **Backup Configuration**
   - Export Terraform state to S3
   - Document configuration parameters
   - Set up automated backups if using RDS

4. **Monitoring Setup**
   - Configure CloudWatch dashboards
   - Set up SNS notifications for alarms
   - Enable Container Insights

---

## Success Criteria

✅ **VPC Infrastructure**
- VPC with public/private subnets deployed
- NAT gateways functional
- Security groups configured

✅ **DNS Configuration**
- superblocks.oiiro.com hosted zone created
- NS delegation configured in parent zone
- DNS resolution working

✅ **SSL/TLS**
- ACM certificate issued and validated
- HTTPS connectivity functional

✅ **Load Balancer**
- Internal ALB deployed and healthy
- Target group with healthy targets
- HTTPS listener configured

✅ **ECS Service**
- Cluster operational
- Service running desired count
- Tasks healthy and stable

✅ **Application Access**
- agent.superblocks.oiiro.com accessible via HTTPS
- Superblocks agent responding to health checks
- Agent registered in Superblocks dashboard

The deployment is complete when all success criteria are met and the Superblocks agent is accessible at `https://agent.superblocks.oiiro.com`.