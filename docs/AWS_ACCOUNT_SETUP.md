# AWS Account Setup for Superblocks Deployment

This guide covers the prerequisite setup for the new AWS account before deploying Superblocks infrastructure.

## 1. AWS Account Creation

1. **Create New AWS Account**
   - Sign up for a new AWS account at https://aws.amazon.com/
   - Use account name: "superblocks" (or similar descriptive name)
   - Complete email verification and billing setup
   - Note the AWS Account ID for configuration

## 2. IAM User Setup

### Create Deployment User
Create an IAM user with programmatic access for Terraform deployments:

```bash
# User name: superblocks-terraform-user
# Access type: Programmatic access only
```

### Required IAM Permissions
Attach the following AWS managed policies to the user:

- `PowerUserAccess` (recommended for simplicity)
- Or create custom policy with these specific permissions:
  - EC2: Full access for VPC, subnets, security groups
  - ECS: Full access for cluster and service management
  - ELB: Full access for Application Load Balancer
  - IAM: Limited access for role creation
  - CloudWatch: Full access for logging and monitoring
  - Route53: Full access (if using custom domain)
  - ACM: Full access for SSL certificates
  - Systems Manager: Parameter Store access

### Custom Policy Example (Optional)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "ecs:*",
                "elasticloadbalancing:*",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:PassRole",
                "iam:GetRole",
                "iam:ListRolePolicies",
                "iam:GetRolePolicy",
                "logs:*",
                "ssm:GetParameter",
                "ssm:PutParameter",
                "ssm:DeleteParameter",
                "route53:*",
                "acm:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## 3. AWS CLI Configuration

### Install AWS CLI
```bash
# macOS (using Homebrew)
brew install awscli

# Verify installation
aws --version
```

### Configure AWS Profile
```bash
# Configure new profile
aws configure --profile superblocks

# Enter when prompted:
# AWS Access Key ID: [from IAM user]
# AWS Secret Access Key: [from IAM user]
# Default region: us-east-1
# Default output format: json
```

### Test Configuration
```bash
# Verify access
aws sts get-caller-identity --profile superblocks

# Expected output should show:
# - UserId: Your IAM user ID
# - Account: Your AWS account number
# - Arn: arn:aws:iam::ACCOUNT-ID:user/superblocks-terraform-user
```

## 4. Terraform Prerequisites

### Install Required Tools
```bash
# Install Terraform
brew install terraform

# Install jq for JSON processing
brew install jq

# Verify installations
terraform version
jq --version
```

### Set Environment Variables (Optional)
```bash
# Add to ~/.bashrc or ~/.zshrc
export AWS_PROFILE=superblocks
export AWS_DEFAULT_REGION=us-east-1
```

## 5. Superblocks Agent Key

### Obtain Agent Key
1. **Log into Superblocks Dashboard**
   - Visit https://app.superblocks.com
   - Navigate to Settings → On-Premise Agent
   - Click "Create New Agent"
   - Copy the generated agent key

2. **Update Configuration**
   ```bash
   # Edit the environment file
   vi /Users/rohitiyer/oiiro/superblocks/terraform/environments/superblocks.tfvars
   
   # Replace this line:
   superblocks_agent_key = "your-superblocks-agent-key-here"
   
   # With your actual key:
   superblocks_agent_key = "sb_agent_xxxxxxxxxxxxxxxxxxxxx"
   ```

## 6. Domain Configuration (Optional)

If you want to use a custom domain instead of the default ALB DNS name:

### Using Existing Domain
1. **Update Route53 Zone ID**
   ```bash
   # Find your hosted zone ID
   aws route53 list-hosted-zones --profile superblocks
   
   # Update superblocks.tfvars:
   domain = "yourdomain.com"
   subdomain = "superblocks"
   route53_zone_id = "Z1D633PJN98FT9"
   create_route53_record = true
   ```

### Using New Domain
1. **Register domain in Route53**
2. **Update configuration with new zone ID**

## 7. SSL Certificate (Optional)

### Option 1: Auto-Generated Certificate
- Leave `certificate_arn` empty in tfvars
- Terraform will create and validate certificate automatically

### Option 2: Existing Certificate
```bash
# List existing certificates
aws acm list-certificates --region us-east-1 --profile superblocks

# Update superblocks.tfvars:
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"
```

## 8. Cost Optimization Settings

For temporary/development use, consider these cost optimization settings in `superblocks.tfvars`:

```hcl
# Reduce instance sizes
cpu_units = 1024     # 1 vCPU instead of 2
memory_units = 2048  # 2GB instead of 4GB

# Reduce scaling
desired_count = 1
min_capacity = 1
max_capacity = 3

# Shorter log retention
log_retention_in_days = 3

# Single NAT gateway
single_nat_gateway = true
nat_gateway_count = 1
```

## 9. Security Considerations

### Network Access
Update `alb_allowed_cidrs` in tfvars to restrict access:

```hcl
# Restrict to your IP or office network
alb_allowed_cidrs = ["YOUR.PUBLIC.IP.ADDRESS/32"]

# Or allow specific CIDR blocks
alb_allowed_cidrs = ["203.0.113.0/24"]  # Replace with your network
```

### Agent Key Security
- Never commit the actual agent key to version control
- Use environment variables or AWS Systems Manager Parameter Store
- The deployment automatically stores the key in SSM Parameter Store

## 10. Pre-Deployment Checklist

Before running the deployment script, verify:

- [ ] AWS CLI configured with correct profile
- [ ] IAM permissions verified
- [ ] Terraform and jq installed
- [ ] Superblocks agent key obtained and configured
- [ ] Network access restrictions configured (alb_allowed_cidrs)
- [ ] Domain/SSL configuration complete (if using custom domain)
- [ ] Cost optimization settings reviewed

## 11. Ready to Deploy

Once all prerequisites are complete, proceed with deployment:

```bash
cd /Users/rohitiyer/oiiro/superblocks
./scripts/deploy.sh deploy superblocks
```

The deployment script will:
1. Verify all prerequisites
2. Deploy VPC infrastructure
3. Deploy Superblocks application
4. Display access URLs and connection information

## Troubleshooting

### Common Issues

**AWS CLI Permission Errors**
```bash
# Verify current identity
aws sts get-caller-identity --profile superblocks

# Check attached policies
aws iam list-attached-user-policies --user-name superblocks-terraform-user --profile superblocks
```

**Terraform State Issues**
```bash
# Initialize Terraform in each module
cd terraform/vpc && terraform init
cd ../superblocks && terraform init
```

**Invalid Agent Key**
- Verify the key starts with "sb_agent_"
- Ensure no extra spaces or characters
- Generate new key from Superblocks dashboard if needed

For additional troubleshooting, refer to the main [SETUP_GUIDE.md](SETUP_GUIDE.md).