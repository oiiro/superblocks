# Simplified Superblocks Deployment on AWS

Terraform infrastructure for deploying Superblocks agent on AWS using ECS Fargate with minimal complexity.

## Overview

This repository provides a **simplified** infrastructure stack for deploying Superblocks on AWS:

✅ **Simple Setup:**
- VPC with public/private subnets across multiple availability zones
- ECS Fargate cluster for running Superblocks containers  
- Application Load Balancer (HTTP access)
- Auto-scaling, monitoring, and logging
- Secure secrets management with AWS Systems Manager

❌ **Removed Complexities:**
- No Route53 DNS management
- No SSL certificate setup
- No cross-account configurations
- No custom domain requirements

## Choose Your Implementation

We provide **4 different implementations** - see [Implementation Comparison](docs/IMPLEMENTATION_COMPARISON.md) for details:

1. **superblocks-simple** - HTTP only, no SSL (simplest)
2. **superblocks-simple-https** - HTTPS with self-signed cert (recommended)
3. **superblocks** - Official module with bugs (not recommended)
4. **apply-workaround.sh** - Script to fix official module

## Quick Start

### Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.0
3. AWS CLI configured
4. Superblocks agent key

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/oiiro/superblocks.git
   cd superblocks
   ```

2. **Get Superblocks agent key**
   - Go to https://app.superblocks.com → Settings → On-Premise Agent
   - Create new agent and copy the key

3. **Configure environment**
   ```bash
   # Edit environment configuration
   vi terraform/environments/superblocks.tfvars
   # Replace: superblocks_agent_key = "sb_agent_your-actual-key"
   ```

4. **Deploy infrastructure**
   ```bash
   ./scripts/deploy.sh deploy superblocks
   ```

5. **Access agent**
   - Access via: `http://<load-balancer-dns>`
   - Add this URL to your Superblocks dashboard

## Documentation

**Quick Start:**
- [Implementation Comparison](docs/IMPLEMENTATION_COMPARISON.md) - **START HERE** - Compare all 4 deployment options
- [Simple Deployment Guide](docs/SIMPLE_DEPLOYMENT.md) - HTTP-only deployment walkthrough

**Troubleshooting:**
- [Module Error Workaround](docs/MODULE_ERROR_WORKAROUND.md) - Fix for official module bugs
- [HTTPS Workaround](docs/HTTPS_WORKAROUND.md) - SSL certificate solutions

**Advanced (Optional):**
- [Setup Guide](docs/SETUP_GUIDE.md) - Complete deployment with Route53
- [AWS Account Setup](docs/AWS_ACCOUNT_SETUP.md) - Prerequisites and AWS configuration
- [Step-by-Step Deployment](docs/STEP_BY_STEP_DEPLOYMENT.md) - Detailed sequential guide

## Project Structure

```
.
├── docs/                    # Documentation
├── terraform/              # Infrastructure as Code
│   ├── vpc/               # VPC module
│   ├── superblocks/       # Superblocks deployment
│   └── environments/      # Environment configurations
└── scripts/               # Automation scripts
```

## Environment Configuration

The project supports multiple environments through `.tfvars` files:

- `superblocks.tfvars` - Default isolated deployment
- `production.tfvars.example` - Production configuration template

## Key Features

- **Simplified Setup**: No DNS or SSL complexity
- **Modular Design**: Separate VPC and application modules
- **Auto-scaling**: Dynamic capacity based on CPU utilization
- **Security**: Private subnets, security groups, encrypted secrets
- **Monitoring**: CloudWatch logs, metrics, and alarms
- **HTTP Access**: Direct load balancer access
- **Cost Optimization**: Configurable instance sizes and scaling

## Operations

### Check Status
```bash
./scripts/deploy.sh status
```

### Update Deployment
```bash
# Update configuration in tfvars
./scripts/deploy.sh deploy superblocks
```

### Destroy Infrastructure
```bash
./scripts/deploy.sh destroy superblocks
```

## Security Considerations

- Agent keys stored in AWS Systems Manager Parameter Store
- Network isolation with VPC and security groups
- HTTP traffic (add SSL later if needed)
- IAM roles with least privilege principle
- Configurable internal/external load balancer

## Cost Management

Default configuration is optimized for development/testing:
- 2 vCPU, 4GB RAM per container
- Auto-scaling between 1-5 instances
- NAT gateway for private subnet internet access
- Public load balancer by default (change to internal for security)

For production, adjust resources in environment configuration.

## Troubleshooting

Common issues and solutions:

1. **Agent Key Issues**: Verify key format (starts with `sb_agent_`)
2. **Deployment Failures**: Check AWS credentials and permissions
3. **Health Check Failures**: Verify security groups and target groups
4. **HTTP Access**: No HTTPS - use `http://` not `https://`

For detailed troubleshooting, see [Simple Deployment Guide](docs/SIMPLE_DEPLOYMENT.md#troubleshooting).

## Support

For issues or questions:
- Review documentation in `/docs`
- Check deployment logs: `terraform/vpc/` and `terraform/superblocks/`
- Verify AWS resources in console

## License

Internal OIIRO project - Not for external distribution

## Acknowledgments

Built using [Superblocks Terraform Modules](https://github.com/superblocksteam/terraform-aws-superblocks)