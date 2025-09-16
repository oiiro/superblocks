# Superblocks AWS Deployment Setup Guide

## Overview

This guide provides a complete step-by-step process for deploying Superblocks in a new AWS account using Terraform. This is designed as an isolated, standalone installation that can be easily removed after use.

## Project Structure

```
superblocks/
├── terraform/           # Terraform configurations
│   ├── vpc/            # VPC and networking setup
│   ├── superblocks/    # Main Superblocks deployment
│   └── outputs/        # Shared outputs and data sources
├── docs/               # Documentation
├── scripts/            # Helper scripts for deployment
└── README.md
```

## Prerequisites

### AWS Account Setup
1. **New AWS Account**: Create dedicated "superblocks" workload account
2. **AWS CLI**: Configured with appropriate credentials
3. **Terraform**: Version 1.0+ installed
4. **Superblocks Agent Key**: Generated from Superblocks Dashboard

### Required Permissions
The deploying user/role needs permissions for:
- VPC management (EC2, VPC)
- ECS cluster and service management
- Application Load Balancer (ALB) management
- IAM role and policy management
- Security Group management
- Route53 (if using custom domain)
- ACM (for SSL certificates)

## Deployment Sequence

### Phase 1: Network Infrastructure Setup

#### Step 1: VPC and Networking
```bash
cd terraform/vpc
terraform init
terraform plan -var-file="../environments/superblocks.tfvars"
terraform apply
```

**Components deployed:**
- VPC with public and private subnets
- Internet Gateway
- NAT Gateways for private subnets
- Route tables and routing
- Security groups for ALB and ECS

#### Step 2: Certificate Management (Optional)
```bash
cd terraform/certificates
terraform init
terraform plan -var-file="../environments/superblocks.tfvars"
terraform apply
```

### Phase 2: Superblocks Application Deployment

#### Step 3: Superblocks ECS Deployment
```bash
cd terraform/superblocks
terraform init
terraform plan -var-file="../environments/superblocks.tfvars"
terraform apply
```

**Components deployed:**
- ECS Cluster
- ECS Service and Task Definition
- Application Load Balancer
- Target Groups
- Auto Scaling configuration

## Configuration Variables

### Required Variables

```hcl
# AWS Account and Region
aws_region = "us-east-1"
aws_account_id = "123456789012"

# Superblocks Configuration
superblocks_agent_key = "your-agent-key-here"
domain = "superblocks.yourdomain.com"
subdomain = "app"

# Network Configuration
vpc_cidr = "10.100.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Instance Configuration
ecs_instance_type = "t3.large"
min_capacity = 1
max_capacity = 5
desired_capacity = 2
```

### Optional Variables

```hcl
# Security
enable_detailed_monitoring = true
enable_container_insights = true

# Networking
create_nat_gateway = true
single_nat_gateway = false

# SSL/TLS
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234"
ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"

# Custom Tags
tags = {
  Project     = "Superblocks"
  Environment = "standalone"
  Owner       = "Platform Team"
  Purpose     = "Temporary Deployment"
}
```

## Security Considerations

### Network Security
- Private subnets for ECS tasks
- Public subnets only for load balancer
- Restrictive security group rules
- No direct internet access to application containers

### IAM Security
- Principle of least privilege
- Separate execution and task roles
- No hardcoded credentials
- Use of AWS Systems Manager for secrets

### Application Security
- HTTPS termination at load balancer
- Container-level security scanning
- Regular base image updates

## Monitoring and Logging

### CloudWatch Integration
- Container insights enabled
- Application logs centralized
- Custom metrics for Superblocks

### Alerting
- ECS service health monitoring
- Load balancer health checks
- Resource utilization alerts

## Scaling Configuration

### Auto Scaling
- CPU-based scaling policies
- Target tracking scaling
- Scale-in protection during deployments

### Load Balancer
- Multi-AZ deployment
- Health check configuration
- Connection draining

## Backup and Disaster Recovery

### Data Persistence
- EFS for persistent storage (if required)
- Database backup configuration
- Configuration backup

### Recovery Procedures
- Infrastructure as Code for rapid rebuild
- Documented rollback procedures
- Backup restoration process

## Cost Optimization

### Resource Sizing
- Right-sized instances based on workload
- Spot instances for development
- Reserved instances for production

### Monitoring
- Cost allocation tags
- Regular cost reviews
- Automated cost alerts

## Cleanup and Decommissioning

### Removal Sequence
1. **Application Cleanup**
   ```bash
   cd terraform/superblocks
   terraform destroy -var-file="../environments/superblocks.tfvars"
   ```

2. **Certificate Cleanup** (if created)
   ```bash
   cd terraform/certificates
   terraform destroy -var-file="../environments/superblocks.tfvars"
   ```

3. **Network Infrastructure Cleanup**
   ```bash
   cd terraform/vpc
   terraform destroy -var-file="../environments/superblocks.tfvars"
   ```

### Verification Steps
- Confirm all resources are deleted
- Check for any remaining costs
- Verify no orphaned resources

## Troubleshooting

### Common Issues
1. **ECS Service Won't Start**
   - Check task definition
   - Verify security group rules
   - Review CloudWatch logs

2. **Load Balancer Health Checks Failing**
   - Verify target group configuration
   - Check application health endpoint
   - Review security group connectivity

3. **Certificate Issues**
   - Verify domain ownership
   - Check Route53 configuration
   - Confirm certificate validation

### Support Resources
- Superblocks Documentation
- AWS ECS Documentation
- Terraform AWS Provider Documentation

## Security Compliance

### AWS Best Practices
- VPC Flow Logs enabled
- CloudTrail logging
- GuardDuty monitoring
- Config rules compliance

### Superblocks Security
- Agent key rotation
- Regular security updates
- Access control configuration

## Next Steps

After successful deployment:
1. Configure Superblocks application settings
2. Set up user access and permissions
3. Configure integrations and data sources
4. Implement monitoring and alerting
5. Plan for regular maintenance and updates

---

**Note**: This is a temporary deployment setup. Ensure proper planning for data backup and migration before decommissioning.