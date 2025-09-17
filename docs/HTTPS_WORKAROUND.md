# HTTPS Listener Workaround for Superblocks

## Problem

The official Superblocks Terraform module (`superblocksteam/superblocks/aws`) requires an HTTPS listener on the Application Load Balancer, even when you don't want to use Route53 or manage SSL certificates. This causes the error:

```
Error creating ELBV2 listener: ValidationError: A certificate must be specified for HTTPS listeners
```

## Solution

We've implemented a workaround using a self-signed certificate that allows the module to create the HTTPS listener without requiring Route53 or ACM certificate validation.

## How It Works

1. **Self-Signed Certificate Generation**
   - Terraform generates a private key and self-signed certificate
   - Certificate is imported into AWS ACM
   - Valid for 1 year with Common Name: `superblocks.local`

2. **Module Configuration**
   - Provides dummy domain (`superblocks.local`) to satisfy module requirements
   - Disables Route53 DNS creation (`create_dns = false`)
   - Disables ACM certificate creation (`create_certs = false`)
   - Uses our self-signed certificate (`certificate_arn`)

## Deployment Steps

### 1. Initialize Terraform (if not done)
```bash
cd terraform/superblocks
terraform init
```

### 2. Apply Configuration
```bash
terraform apply -var-file="../environments/superblocks.tfvars"
```

### 3. Access the Agent
```bash
# Get the load balancer URL
terraform output load_balancer_dns_name

# Access via HTTPS (you'll see SSL warnings)
https://superblocks-alb-1234567890.us-east-1.elb.amazonaws.com
```

## Handling SSL Warnings

Since we're using a self-signed certificate, you'll see SSL warnings when accessing the agent:

### Browser Access
1. Navigate to the URL
2. You'll see a security warning
3. Click **"Advanced"** or **"Show Details"**
4. Click **"Proceed to site"** or **"Accept the Risk and Continue"**

### Command Line Access
```bash
# Ignore SSL verification (for testing only)
curl -k https://your-alb-dns-name/health

# Or with wget
wget --no-check-certificate https://your-alb-dns-name/health
```

### Superblocks Dashboard
When adding the agent to Superblocks dashboard:
1. Use the HTTPS URL: `https://your-alb-dns-name`
2. The Superblocks platform should accept self-signed certificates for on-premise agents
3. If issues occur, contact Superblocks support

## Alternative Solutions

### Option 1: Use a Real Certificate
If you have a domain and certificate:
```hcl
# In superblocks.tfvars
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"
```

### Option 2: Fork and Modify Module
Fork the official module and modify it to support HTTP-only listeners.

### Option 3: Use Network Load Balancer
Some modules support NLB with TCP listeners that don't require certificates.

## Security Considerations

- **Self-signed certificates** are acceptable for internal/development use
- **Production environments** should use proper SSL certificates
- **Internal load balancers** (with VPN/bastion access) reduce exposure

## Troubleshooting

### Certificate Creation Failed
```bash
# Check if TLS provider is initialized
terraform init -upgrade

# Verify certificate resource
terraform state show aws_acm_certificate.superblocks
```

### HTTPS Listener Still Failing
```bash
# Ensure certificate is created first
terraform apply -target=aws_acm_certificate.superblocks
terraform apply
```

### Agent Not Accessible
1. Check security groups allow HTTPS (port 443)
2. Verify target group health checks
3. Check ECS tasks are running

## Clean Up

To remove the self-signed certificate when destroying:
```bash
terraform destroy -var-file="../environments/superblocks.tfvars"
```

## Summary

This workaround allows you to deploy Superblocks without managing Route53 or real SSL certificates while satisfying the module's HTTPS requirement. The self-signed certificate is automatically generated and managed by Terraform.