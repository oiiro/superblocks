# Superblocks Private Agent Deployment Dependencies

## Overview
Complete dependency analysis for deploying Superblocks private agent using Terraform with domain `agent.superblocks.oiiro.com` and cross-account DNS management.

## Prerequisites

### 1. AWS Accounts
- **Superblocks Account**: New AWS account for Superblocks deployment
- **Shared Services Account**: OIIRO cloudforge project manages oiiro.com hosted zone

### 2. Tools Required
```bash
# Required versions
terraform >= 1.5.0
aws-cli >= 2.0
jq >= 1.6
```

### 3. AWS Permissions
**Superblocks Account:**
- VPC management (EC2 full access)
- ECS full access
- ELB/ALB full access
- IAM role creation and attachment
- Route53 subdomain creation
- ACM certificate management
- CloudWatch logs and metrics
- Secrets Manager (optional)

**Shared Services Account:**
- Route53 hosted zone delegation (NS record creation)

## Infrastructure Dependencies (Sequential Order)

### Phase 1: Network Foundation
1. **VPC** - Virtual Private Cloud
   - CIDR block allocation
   - DNS hostnames and resolution enabled
   - Internet Gateway attachment

2. **Subnets**
   - Public subnets (minimum 2 AZs) for Load Balancer
   - Private subnets (minimum 2 AZs) for ECS tasks
   - Route tables configuration

3. **NAT Gateways**
   - One per AZ for private subnet internet access
   - Elastic IP allocation

4. **Security Groups**
   - Load Balancer security group (HTTPS ingress)
   - ECS task security group (container communication)

### Phase 2: DNS and Certificates
5. **Route53 Hosted Zone** (Subdomain)
   - Create `superblocks.oiiro.com` hosted zone in Superblocks account
   - Extract NS records for delegation

6. **Cross-Account DNS Delegation**
   - Add NS records in `oiiro.com` hosted zone (shared services account)
   - Point `superblocks.oiiro.com` to Superblocks account NS servers

7. **ACM Certificate**
   - Request certificate for `agent.superblocks.oiiro.com`
   - DNS validation using Route53

### Phase 3: Load Balancer
8. **Application Load Balancer**
   - Internal ALB in private subnets (for private agent)
   - HTTPS listener with ACM certificate
   - Target group for ECS service

### Phase 4: Container Infrastructure
9. **ECS Cluster**
   - Fargate capacity provider
   - Container insights enabled

10. **IAM Roles**
    - Task execution role (ECR, CloudWatch access)
    - Task role (AWS service access for Superblocks)

11. **ECS Service and Task Definition**
    - Superblocks agent container
    - Environment variables configuration
    - Service discovery integration

### Phase 5: Database (Optional)
12. **RDS Subnet Group**
    - Private subnets for database

13. **RDS Instance**
    - PostgreSQL for Superblocks metadata
    - Security group for ECS access only

### Phase 6: Secrets Management
14. **AWS Secrets Manager**
    - Superblocks agent key storage
    - Database credentials (if using RDS)

### Phase 7: Monitoring
15. **CloudWatch Log Groups**
    - ECS task logs
    - Application logs

16. **CloudWatch Alarms**
    - ECS service health
    - ALB target health

## Required Configuration Parameters

### Superblocks Agent Configuration
```hcl
superblocks_agent_key = "sb_agent_xxxxxxxxxxxxxxxxxxxxx"  # From Superblocks dashboard
domain = "superblocks.oiiro.com"
subdomain = "agent"
superblocks_server_url = "https://api.superblocks.com"
superblocks_agent_data_domain = "app.superblocks.com"
```

### Network Configuration
```hcl
create_vpc = true
vpc_cidr = "10.100.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.100.1.0/24", "10.100.2.0/24"]
private_subnet_cidrs = ["10.100.10.0/24", "10.100.20.0/24"]
```

### Load Balancer Configuration
```hcl
create_lb = true
lb_internal = true  # Private agent uses internal ALB
create_dns = true
create_certs = true
```

### Container Configuration
```hcl
container_cpu = 1024      # 1 vCPU
container_memory = 2048   # 2 GB
container_min_capacity = 1
container_max_capacity = 5
```

## Cross-Account DNS Setup

### Step 1: Create Subdomain Hosted Zone
```bash
# In Superblocks account
aws route53 create-hosted-zone \
  --name superblocks.oiiro.com \
  --caller-reference "superblocks-$(date +%s)"
```

### Step 2: Extract NS Records
```bash
# Get the NS records from the new hosted zone
aws route53 get-hosted-zone --id /hostedzone/Z1234567890ABC \
  --query 'DelegationSet.NameServers'
```

### Step 3: Delegate in Parent Zone
```bash
# In shared services account (oiiro.com zone)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z0987654321XYZ \
  --change-batch '{
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

## Deployment Sequence

### Phase 1: Foundation (VPC)
```bash
cd terraform/vpc
terraform init
terraform plan -var-file="../environments/superblocks.tfvars"
terraform apply
```

### Phase 2: DNS Delegation
```bash
# Extract NS records from VPC output
# Manually create delegation in shared services account
```

### Phase 3: Superblocks Deployment
```bash
cd terraform/superblocks
terraform init
terraform plan -var-file="../environments/superblocks.tfvars"
terraform apply
```

## Environment Variables Needed

### Required
- `superblocks_agent_key` - From Superblocks setup wizard
- `domain` - "superblocks.oiiro.com"
- `subdomain` - "agent"

### Optional
- `superblocks_agent_tags` - Environment tagging
- `superblocks_agent_environment` - Environment filtering
- Database credentials (if using RDS)

## Security Considerations

### Network Security
- Private agent uses internal load balancer
- ECS tasks in private subnets only
- Security groups restrict access to necessary ports only

### Secrets Management
- Agent key stored in AWS Secrets Manager or SSM Parameter Store
- Database credentials encrypted at rest
- Container environment variables reference secrets, not plain text

### Access Control
- IAM roles follow least privilege principle
- Cross-account access limited to DNS delegation only
- VPC flow logs for network monitoring

## Validation Steps

1. **DNS Resolution**
   ```bash
   nslookup agent.superblocks.oiiro.com
   ```

2. **Certificate Validation**
   ```bash
   curl -I https://agent.superblocks.oiiro.com
   ```

3. **ECS Service Health**
   ```bash
   aws ecs describe-services --cluster superblocks --services superblocks-agent
   ```

4. **Load Balancer Targets**
   ```bash
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   ```

## Common Issues and Solutions

### DNS Propagation
- Wait 5-10 minutes after NS delegation
- Use `dig +trace agent.superblocks.oiiro.com` to verify delegation path

### Certificate Validation
- Ensure DNS validation records are created
- Check ACM certificate status in AWS console

### ECS Task Failures
- Check CloudWatch logs for container startup errors
- Verify agent key is valid and accessible
- Confirm security groups allow necessary traffic

### Cross-Account Access
- Verify IAM permissions for Route53 delegation
- Confirm shared services account has correct hosted zone ID