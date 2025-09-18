# Superblocks on AWS - Simple Deployment

Deploy Superblocks agent on AWS using Terraform with ECS Fargate.

## Quick Start

### 1. Get Your Agent Key
1. Go to https://app.superblocks.com
2. Settings → On-Premise Agent → Create New Agent
3. Copy the agent key (starts with `sb_agent_`)

### 2. Configure
```bash
# Edit the agent key
vi terraform/environments/superblocks.tfvars

# Replace this line:
superblocks_agent_key = "sb_agent_your-actual-key-here"
# With your actual key:
superblocks_agent_key = "sb_agent_xxxxxxxxxxxxx"
```

### 3. Deploy

**HTTP Version (Simple):**
```bash
./deploy-http.sh
```

**HTTPS Version (With SSL):**
```bash
./deploy-https.sh
```

### 4. Access
The script will output your agent URL. Add this URL to your Superblocks dashboard.

## Deployment Options

| Version | Command | Protocol | Use Case |
|---------|---------|----------|----------|
| **HTTP** | `./deploy-http.sh` | HTTP only | Development, testing |
| **HTTPS** | `./deploy-https.sh` | HTTPS (self-signed) | Production, security |

## Architecture

Both versions deploy:
- **VPC**: Public/private subnets, NAT gateways
- **ECS**: Fargate cluster with Superblocks agent
- **ALB**: Application Load Balancer
- **IAM**: Execution and task roles
- **CloudWatch**: Logging and monitoring

**The only difference:** HTTP vs HTTPS listener configuration.

## Management

### Check Status
```bash
cd terraform/superblocks-simple  # or superblocks-simple-https
terraform output
```

### View Logs
```bash
aws logs tail /ecs/superblocks --follow
```

### Cleanup Everything
```bash
./cleanup.sh
```

## Project Structure

```
.
├── deploy-http.sh              # Deploy HTTP version
├── deploy-https.sh             # Deploy HTTPS version  
├── cleanup.sh                  # Remove everything
├── terraform/
│   ├── modules/
│   │   └── superblocks_agent/  # Reusable module
│   ├── vpc/                    # VPC infrastructure
│   ├── superblocks-simple/     # HTTP deployment
│   ├── superblocks-simple-https/ # HTTPS deployment
│   └── environments/
│       └── superblocks.tfvars  # Configuration
└── docs/
    ├── SIMPLE_DEPLOYMENT.md    # Detailed guide
    └── MODULE_STRUCTURE.md     # Technical details
```

## Cost Optimization

Default configuration:
- 1 vCPU, 2GB RAM
- Auto-scaling 1-3 instances
- 7-day log retention

To reduce costs, edit `terraform/environments/superblocks.tfvars`:
```hcl
cpu_units = 512      # Reduce CPU
memory_units = 1024  # Reduce memory
desired_count = 1    # Single instance
max_capacity = 1     # No auto-scaling
```

## Troubleshooting

### Agent Not Connecting
1. Check ECS tasks: `aws ecs describe-services --cluster superblocks-cluster --services superblocks-agent`
2. Check logs: `aws logs tail /ecs/superblocks --follow`
3. Verify agent key is correct

### Deployment Fails
1. Check AWS credentials: `aws sts get-caller-identity`
2. Verify agent key format (starts with `sb_agent_`)
3. Ensure no existing resources conflict

### SSL Warnings (HTTPS version)
This is expected with self-signed certificates. Click "Advanced" → "Proceed" in your browser.

## Advanced Usage

### Switch Between Versions
```bash
# Destroy current deployment
./cleanup.sh

# Deploy different version
./deploy-https.sh  # or ./deploy-http.sh
```

### Use Real SSL Certificate
Edit `terraform/environments/superblocks.tfvars`:
```hcl
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"
```

## Support

- **Documentation**: See `docs/` folder
- **Issues**: Check CloudWatch logs and ECS service status
- **Costs**: Monitor AWS billing dashboard

## License

Internal OIIRO project