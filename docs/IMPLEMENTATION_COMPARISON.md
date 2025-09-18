# Superblocks Implementation Comparison Guide

## Overview

This project provides **FOUR** different implementations for deploying Superblocks on AWS. Each has different trade-offs regarding complexity, SSL support, and module usage.

## Implementation Comparison Table

| Implementation | Path | SSL/HTTPS | Module Used | Complexity | Status |
|---------------|------|-----------|-------------|------------|--------|
| **superblocks** | `/terraform/superblocks` | ✅ HTTPS (self-signed) | Official (buggy) | High | ⚠️ Has count error |
| **superblocks-simple** | `/terraform/superblocks-simple` | ❌ HTTP only | None (direct) | Low | ✅ Works |
| **superblocks-simple-https** | `/terraform/superblocks-simple-https` | ✅ HTTPS (self-signed) | None (direct) | Medium | ✅ Works |
| **apply-workaround** | `/scripts/apply-workaround.sh` | ✅ HTTPS (self-signed) | Official (staged) | Medium | ✅ Works |

## Detailed Comparison

### 1. Official Module with Self-Signed Cert (`/terraform/superblocks`)

**Features:**
- Uses official `superblocksteam/superblocks/aws` module
- Self-signed certificate for HTTPS
- Full module features

**Issues:**
- ⚠️ **Has count error**: `count = var.ssl_enable ? 1 : 0` causes Terraform apply failures
- Requires workaround script or manual staged apply
- Complex to debug

**When to Use:**
- Never directly (use workaround script instead)
- Only if you must use the official module

### 2. Simple HTTP Implementation (`/terraform/superblocks-simple`)

**Features:**
- Direct resource creation (no module)
- HTTP only on port 80
- Simplest implementation
- Full control over resources

**Benefits:**
- ✅ No SSL complexity
- ✅ No certificate warnings
- ✅ Works immediately
- ✅ Easy to debug and modify

**Limitations:**
- ❌ No HTTPS (security consideration)
- ❌ No encryption in transit

**When to Use:**
- Development/testing environments
- Internal networks with VPN
- Quick proof of concept
- When SSL is not required

### 3. Simple HTTPS Implementation (`/terraform/superblocks-simple-https`)

**Features:**
- Direct resource creation (no module)
- HTTPS with self-signed certificate
- HTTP to HTTPS redirect
- Auto-scaling support

**Benefits:**
- ✅ HTTPS encryption
- ✅ No module bugs
- ✅ Full control
- ✅ Works reliably

**Limitations:**
- ⚠️ Self-signed cert warnings
- Slightly more complex than HTTP version

**When to Use:**
- When HTTPS is required
- Production environments (replace cert later)
- Security-conscious deployments
- Don't want module dependencies

### 4. Workaround Script (`/scripts/apply-workaround.sh`)

**Features:**
- Uses official module with staged apply
- Works around the count error
- Automated fix for module bug

**Benefits:**
- ✅ Uses official module
- ✅ Automated workaround

**Limitations:**
- Still relies on buggy module
- Less transparent than direct implementations

**When to Use:**
- If you must use official module
- Want module updates/support

## Resource Creation Comparison

| Resource | Official Module | Simple | Simple-HTTPS |
|----------|----------------|--------|--------------|
| ECS Cluster | ✅ Auto | ✅ Manual | ✅ Manual |
| ALB | ✅ Auto | ✅ Manual | ✅ Manual |
| Target Groups | ✅ Auto | ✅ Manual | ✅ Manual |
| SSL Certificate | ✅ Self-signed | ❌ None | ✅ Self-signed |
| HTTPS Listener | ✅ Yes | ❌ No | ✅ Yes |
| HTTP Listener | ✅ Redirect | ✅ Forward | ✅ Redirect |
| Security Groups | ✅ Auto | ✅ Manual | ✅ Manual |
| IAM Roles | ✅ Auto | ✅ Manual | ✅ Manual |
| Auto Scaling | ✅ Optional | ❌ No | ✅ Optional |
| CloudWatch Logs | ✅ Auto | ✅ Manual | ✅ Manual |

## ALB Reuse Considerations

**Important:** You **CANNOT** reuse an ALB from a previous deployment:

1. **Each implementation creates its own ALB** with unique:
   - DNS name
   - Security groups
   - Target groups
   - Listeners

2. **To switch implementations:**
   ```bash
   # First, destroy the old implementation
   cd terraform/[old-implementation]
   terraform destroy -var-file="../environments/superblocks.tfvars"
   
   # Then deploy new implementation
   cd ../[new-implementation]
   terraform init
   terraform apply -var-file="../environments/superblocks.tfvars"
   ```

3. **ALB DNS will change** between deployments:
   - Old: `superblocks-alb-123456.us-east-1.elb.amazonaws.com`
   - New: `superblocks-alb-789012.us-east-1.elb.amazonaws.com`

## Deployment Commands

### Simple HTTP (Recommended for Testing)
```bash
cd terraform/superblocks-simple
terraform init
terraform apply -var-file="../environments/superblocks.tfvars"
```

### Simple HTTPS (Recommended for Production)
```bash
cd terraform/superblocks-simple-https
terraform init
terraform apply -var-file="../environments/superblocks.tfvars"
```

### Official Module with Workaround
```bash
cd /Users/rohitiyer/oiiro/superblocks
./scripts/apply-workaround.sh
```

## SSL Certificate Options

### Self-Signed (Current)
- Automatic generation
- Browser warnings
- Free
- Good for testing

### Real Certificate (Future)
To use a real certificate, modify any HTTPS implementation:

```hcl
# Comment out self-signed cert resources
# resource "tls_private_key" "superblocks" { ... }
# resource "tls_self_signed_cert" "superblocks" { ... }
# resource "aws_acm_certificate" "superblocks" { ... }

# Use existing ACM certificate
variable "certificate_arn" {
  default = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"
}

# In ALB listener
certificate_arn = var.certificate_arn
```

## Migration Path

### From Official Module to Simple
```bash
# 1. Note the agent key and configuration
terraform output

# 2. Destroy official module deployment
cd terraform/superblocks
terraform destroy -var-file="../environments/superblocks.tfvars"

# 3. Deploy simple implementation
cd ../superblocks-simple-https
terraform init
terraform apply -var-file="../environments/superblocks.tfvars"
```

### From HTTP to HTTPS
```bash
# 1. Destroy HTTP version
cd terraform/superblocks-simple
terraform destroy -var-file="../environments/superblocks.tfvars"

# 2. Deploy HTTPS version
cd ../superblocks-simple-https
terraform init
terraform apply -var-file="../environments/superblocks.tfvars"
```

## Recommendations

### For Development/Testing
Use **superblocks-simple** (HTTP):
- Fastest deployment
- No SSL complexity
- Easy debugging

### For Production
Use **superblocks-simple-https**:
- HTTPS encryption
- No module dependencies
- Full control
- Add real certificate later

### Avoid
- Direct use of official module (has bugs)
- Mixing implementations (causes conflicts)

## Common Issues

### ALB Already Exists
```bash
Error: ALB with name already exists
```
**Solution:** Destroy previous deployment first

### Certificate Validation
```bash
Error: Certificate validation timeout
```
**Solution:** Self-signed certs don't need validation

### Count Error
```bash
Error: Invalid count argument
```
**Solution:** Use simple implementations or workaround script

## Summary

- **Simplest**: `superblocks-simple` (HTTP only)
- **Best Balance**: `superblocks-simple-https` (HTTPS without module bugs)
- **Official Support**: Use workaround script with official module
- **Production Ready**: `superblocks-simple-https` with real certificate