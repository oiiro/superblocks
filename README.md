# Superblocks Deployment on AWS

Terraform infrastructure for deploying Superblocks application on AWS using ECS Fargate.

## Overview

This repository provides a complete, isolated infrastructure stack for deploying Superblocks on AWS. It includes:

- VPC with public/private subnets across multiple availability zones
- ECS Fargate cluster for running Superblocks containers
- Application Load Balancer with SSL/TLS support
- Auto-scaling, monitoring, and logging
- Secure secrets management with AWS Systems Manager

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

2. **Configure environment**
   ```bash
   # Edit environment configuration
   vi terraform/environments/superblocks.tfvars
   # Add your Superblocks agent key
   ```

3. **Deploy infrastructure**
   ```bash
   ./scripts/deploy.sh deploy superblocks
   ```

4. **Access application**
   - The deployment script will output the application URL
   - Default: `https://<load-balancer-dns>`
   - Custom domain: `https://superblocks.yourdomain.com`

## Documentation

- [Setup Guide](docs/SETUP_GUIDE.md) - Complete deployment walkthrough
- [AWS Account Setup](docs/AWS_ACCOUNT_SETUP.md) - Prerequisites and AWS configuration

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

- **Modular Design**: Separate VPC and application modules
- **Auto-scaling**: Dynamic capacity based on CPU utilization
- **Security**: Private subnets, security groups, encrypted secrets
- **Monitoring**: CloudWatch logs, metrics, and alarms
- **SSL/TLS**: Automatic certificate management
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
- SSL/TLS encryption for all traffic
- IAM roles with least privilege principle
- Optional IP whitelisting for load balancer

## Cost Management

Default configuration is optimized for development/testing:
- 2 vCPU, 4GB RAM per container
- Auto-scaling between 1-5 instances
- NAT gateway for private subnet internet access

For production, adjust resources in environment configuration.

## Troubleshooting

Common issues and solutions:

1. **Agent Key Issues**: Verify key format (starts with `sb_agent_`)
2. **Deployment Failures**: Check AWS credentials and permissions
3. **Health Check Failures**: Verify security groups and target groups

For detailed troubleshooting, see [Setup Guide](docs/SETUP_GUIDE.md#troubleshooting).

## Support

For issues or questions:
- Review documentation in `/docs`
- Check deployment logs: `terraform/vpc/` and `terraform/superblocks/`
- Verify AWS resources in console

## License

Internal OIIRO project - Not for external distribution

## Acknowledgments

Built using [Superblocks Terraform Modules](https://github.com/superblocksteam/terraform-aws-superblocks)