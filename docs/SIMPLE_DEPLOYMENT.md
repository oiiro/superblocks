# Simple Superblocks Deployment Guide

## Overview

This is a simplified deployment guide for Superblocks that removes the complexity of Route53 DNS management and SSL certificates. The agent will be accessible via the AWS Application Load Balancer DNS name over HTTP.

## What's Simplified

❌ **Removed Complexities:**
- No Route53 hosted zone creation
- No cross-account DNS delegation
- No ACM SSL certificate management
- No custom domain configuration
- No HTTPS setup

✅ **Simple Setup:**
- Direct load balancer access via AWS DNS name
- HTTP only (no SSL)
- Single AWS account deployment
- Minimal configuration required

## Prerequisites

### 1. AWS Account Setup
```bash
# Create IAM user with these permissions:
- VPC management (EC2 full access)
- ECS full access
- ELB/ALB full access
- IAM role creation
- CloudWatch logs
- Systems Manager Parameter Store

# Configure AWS CLI
aws configure --profile superblocks
```

### 2. Get Superblocks Agent Key
1. Go to https://app.superblocks.com
2. Navigate to **Settings** → **On-Premise Agent**
3. Click **"Create New Agent"**
4. Copy the agent key (starts with `sb_agent_`)

### 3. Update Configuration
```bash
# Edit the agent key in the configuration
vi terraform/environments/superblocks.tfvars

# Replace this line:
superblocks_agent_key = "sb_agent_your-actual-key-here"

# With your actual key:
superblocks_agent_key = "sb_agent_xxxxxxxxxxxxxxxxxx"
```

## Deployment Steps

### Step 1: Deploy VPC Infrastructure
```bash
cd /Users/rohitiyer/oiiro/superblocks/terraform/vpc

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="../environments/superblocks.tfvars"

# Apply VPC
terraform apply -var-file="../environments/superblocks.tfvars"
```

**Expected Resources Created:**
- 1 VPC (10.100.0.0/16)
- 2 Public subnets
- 2 Private subnets  
- 1 Internet Gateway
- 2 NAT Gateways
- Security groups

### Step 2: Deploy Superblocks Agent
```bash
cd ../superblocks

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="../environments/superblocks.tfvars"

# Apply Superblocks
terraform apply -var-file="../environments/superblocks.tfvars"
```

**Expected Resources Created:**
- ECS Cluster
- ECS Service
- Application Load Balancer
- Target Group
- CloudWatch Log Groups

### Step 3: Get Access URL
```bash
# Get the load balancer DNS name
terraform output load_balancer_dns_name

# Example output:
# superblocks-alb-1234567890.us-east-1.elb.amazonaws.com
```

### Step 4: Access the Agent
```bash
# Your Superblocks agent is accessible at:
http://superblocks-alb-1234567890.us-east-1.elb.amazonaws.com

# Test connectivity
curl http://superblocks-alb-1234567890.us-east-1.elb.amazonaws.com/health
```

## Configuration Options

### Internal vs Public Load Balancer

**Public Load Balancer (Default):**
```hcl
# In superblocks.tfvars
load_balancer_internal = false  # Internet accessible
```

**Internal Load Balancer:**
```hcl
# In superblocks.tfvars  
load_balancer_internal = true   # VPC only access
```

### Resource Sizing
```hcl
# Adjust in superblocks.tfvars
cpu_units = 1024     # 1 vCPU (default: 2048)
memory_units = 2048  # 2 GB (default: 4096)
desired_count = 1    # Single instance (default: 2)
```

## Verification Steps

### 1. Check ECS Service
```bash
aws ecs describe-services \
  --cluster superblocks-cluster \
  --services superblocks-agent \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
```

### 2. Check Load Balancer Health
```bash
# Get target group ARN from outputs
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

### 3. Test Agent Connectivity
```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw load_balancer_dns_name)

# Test health endpoint
curl "http://${ALB_DNS}/health"

# Should return: {"status":"ok"} or similar
```

## Configure in Superblocks Dashboard

1. **Login to Superblocks Dashboard**
   - Go to https://app.superblocks.com

2. **Add Agent**
   - Navigate to **Settings** → **On-Premise Agent**
   - Click **"Add Agent"**
   - Enter the load balancer URL: `http://your-alb-dns-name`

3. **Verify Connection**
   - The agent should appear as "Connected" in the dashboard
   - You can now use this agent for your Superblocks applications

## Troubleshooting

### Agent Not Connecting

1. **Check ECS Tasks**
   ```bash
   aws ecs describe-tasks \
     --cluster superblocks-cluster \
     --tasks $(aws ecs list-tasks --cluster superblocks-cluster --service-name superblocks-agent --query 'taskArns[0]' --output text)
   ```

2. **Check CloudWatch Logs**
   ```bash
   aws logs tail /ecs/superblocks --follow
   ```

3. **Verify Agent Key**
   ```bash
   # Check if key is stored correctly
   aws ssm get-parameter --name "/superblocks/superblocks/agent-key" --with-decryption
   ```

### Load Balancer Issues

1. **Check Target Health**
   ```bash
   aws elbv2 describe-target-health --target-group-arn <arn>
   ```

2. **Check Security Groups**
   ```bash
   # Ensure port 8080 is open for ALB → ECS communication
   aws ec2 describe-security-groups --group-ids <security-group-id>
   ```

### Common Fixes

**Agent Key Invalid:**
- Verify the key starts with `sb_agent_`
- Regenerate key in Superblocks dashboard
- Update terraform/environments/superblocks.tfvars
- Re-run `terraform apply`

**ECS Tasks Failing:**
- Check CloudWatch logs for container errors
- Verify agent key is accessible
- Check network connectivity

## Cleanup

To remove all resources:

```bash
# Destroy Superblocks
cd terraform/superblocks
terraform destroy -var-file="../environments/superblocks.tfvars"

# Destroy VPC
cd ../vpc  
terraform destroy -var-file="../environments/superblocks.tfvars"
```

## Next Steps

Once the simple deployment works:

1. **Add SSL Certificate (Optional)**
   - Import or create ACM certificate
   - Update load balancer to use HTTPS

2. **Add Custom Domain (Optional)**
   - Create Route53 hosted zone
   - Point domain to load balancer

3. **Security Hardening**
   - Make load balancer internal
   - Set up VPN or bastion host access
   - Restrict security group rules

4. **Monitoring**
   - Set up CloudWatch alarms
   - Configure log analysis
   - Monitor agent performance

## Success Criteria

✅ **Deployment Successful When:**
- ECS service shows "ACTIVE" status
- Load balancer targets are "healthy"
- HTTP request to ALB returns agent response
- Superblocks dashboard shows agent as "Connected"

The simplified deployment is complete when you can access the Superblocks agent via the AWS load balancer DNS name and it appears connected in your Superblocks dashboard.