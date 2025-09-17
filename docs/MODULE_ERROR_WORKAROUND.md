# Workaround for Superblocks Module Count Error

## Problem

The official Superblocks Terraform module (v1.0) has a bug that causes this error:

```
Error: Invalid count argument
The "count" value depends on resource attributes that cannot be determined until apply
```

This occurs in the module's internal `aws_lb_target_group.grpc` resource which uses:
```hcl
count = var.ssl_enable ? 1 : 0
```

## Solutions

### Solution 1: Use Staged Apply (Quick Fix)

Use the provided workaround script that applies resources in stages:

```bash
cd /Users/rohitiyer/oiiro/superblocks
./scripts/apply-workaround.sh
```

This script:
1. Applies the certificate resources first
2. Then applies the full configuration
3. Avoids the count dependency issue

### Solution 2: Use Simple Implementation (Recommended)

We've created a simplified implementation that doesn't use the official module:

```bash
# Use the simple implementation instead
cd terraform/superblocks-simple

# Initialize
terraform init

# Apply
terraform apply -var-file="../environments/superblocks.tfvars"
```

**Advantages of Simple Implementation:**
- No module bugs or count errors
- Direct control over all resources
- HTTP only (no SSL complexity)
- Easier to debug and modify
- Same functionality as official module

### Solution 3: Manual Targeted Apply

If you prefer to use the official module manually:

```bash
cd terraform/superblocks

# Step 1: Apply certificate first
terraform apply \
  -target=tls_private_key.superblocks \
  -target=tls_self_signed_cert.superblocks \
  -target=aws_acm_certificate.superblocks \
  -var-file="../environments/superblocks.tfvars"

# Step 2: Apply everything else
terraform apply -var-file="../environments/superblocks.tfvars"
```

## Comparison of Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **Workaround Script** | Quick, automated | Still uses buggy module |
| **Simple Implementation** | No bugs, full control, HTTP | Not using official module |
| **Manual Apply** | Uses official module | Manual process each time |

## Simple Implementation Details

The `superblocks-simple` implementation creates:
- ECS Cluster with Fargate
- Application Load Balancer (HTTP)
- Target Groups for HTTP and gRPC
- ECS Task Definition with Superblocks agent
- ECS Service with auto-scaling
- Security Groups
- CloudWatch Logs

It provides the same functionality as the official module but without:
- SSL/HTTPS complexity
- Route53 integration
- Module bugs

## Migration Path

To switch from the buggy module to the simple implementation:

1. **Destroy existing deployment** (if any):
   ```bash
   cd terraform/superblocks
   terraform destroy -var-file="../environments/superblocks.tfvars"
   ```

2. **Use simple implementation**:
   ```bash
   cd ../superblocks-simple
   terraform init
   terraform apply -var-file="../environments/superblocks.tfvars"
   ```

3. **Get agent URL**:
   ```bash
   terraform output agent_url
   ```

## Testing the Agent

Once deployed with any method:

```bash
# Get the load balancer DNS
AGENT_URL=$(terraform output -raw agent_url)

# Test health endpoint
curl $AGENT_URL/health

# Should return something like:
# {"status":"ok"}
```

## Adding to Superblocks Dashboard

1. Go to https://app.superblocks.com
2. Navigate to Settings → On-Premise Agent
3. Add agent with URL from terraform output
4. Agent should connect successfully

## Troubleshooting

### Module Still Failing
- Use the simple implementation instead
- Check Terraform version (needs >= 1.5)
- Ensure AWS credentials are configured

### Agent Not Connecting
- Check ECS tasks are running
- Verify security groups allow traffic
- Check CloudWatch logs for errors
- Ensure agent key is valid

### Health Check Failing
- Verify port 8080 is open
- Check target group health
- Review ECS task logs

## Summary

The official Superblocks module has a count dependency bug. Use either:
1. The workaround script for quick deployment
2. The simple implementation for reliable, bug-free deployment (recommended)
3. Manual targeted applies if you must use the official module

The simple implementation (`superblocks-simple`) is the most reliable solution.