# DNS Delegation Guide for Superblocks

## Overview

This guide covers setting up DNS delegation for `agent.superblocks.oiiro.com` across two AWS accounts:
- **Superblocks Account**: Hosts the `superblocks.oiiro.com` subdomain
- **Shared Services Account**: Manages the parent `oiiro.com` domain

## Prerequisites

1. **AWS Accounts Configured**
   - Superblocks account with appropriate Route53 permissions
   - OIIRO shared services account with `oiiro.com` hosted zone access

2. **AWS CLI Profiles**
   ```bash
   # Configure profiles
   aws configure --profile superblocks
   aws configure --profile oiiro-shared-services
   ```

3. **Tools Installed**
   ```bash
   # Required tools
   aws --version    # AWS CLI v2+
   jq --version     # JSON processor
   dig             # DNS lookup (optional)
   ```

## Method 1: Automated Script (Recommended)

### Step 1: Use DNS Delegation Script
```bash
cd /Users/rohitiyer/oiiro/superblocks

# Run with default profiles
./scripts/dns-delegation.sh

# Or specify custom profiles
./scripts/dns-delegation.sh superblocks oiiro-shared-services
```

### Step 2: Verify Output
The script will:
1. ✅ Check prerequisites and profiles
2. ✅ Find Superblocks hosted zone
3. ✅ Find parent oiiro.com hosted zone
4. ✅ Extract name servers from Superblocks zone
5. ✅ Create NS delegation record in parent zone
6. ✅ Wait for DNS propagation
7. ✅ Verify delegation works

**Expected Output:**
```
[SUCCESS] === DNS DELEGATION COMPLETED ===
Domain: superblocks.oiiro.com
Parent Zone: oiiro.com
Superblocks Hosted Zone ID: Z1234567890ABC
Parent Hosted Zone ID: Z0987654321XYZ

Name Servers Delegated:
  ns-123.awsdns-12.com
  ns-456.awsdns-34.net
  ns-789.awsdns-56.org
  ns-012.awsdns-78.co.uk
```

## Method 2: Manual Configuration

### Step 1: Get Superblocks Name Servers
```bash
# Switch to Superblocks account
export AWS_PROFILE=superblocks

# Find hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='superblocks.oiiro.com.'].Id" \
  --output text | sed 's|/hostedzone/||')

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# Get name servers
aws route53 get-hosted-zone \
  --id $HOSTED_ZONE_ID \
  --query 'DelegationSet.NameServers' \
  --output table
```

**Sample Output:**
```
---------------------------------
|        NameServers            |
+-------------------------------+
|  ns-123.awsdns-12.com         |
|  ns-456.awsdns-34.net         |
|  ns-789.awsdns-56.org         |
|  ns-012.awsdns-78.co.uk       |
+-------------------------------+
```

### Step 2: Create Delegation in Parent Zone
```bash
# Switch to shared services account
export AWS_PROFILE=oiiro-shared-services

# Find parent zone ID
PARENT_ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='oiiro.com.'].Id" \
  --output text | sed 's|/hostedzone/||')

echo "Parent Zone ID: $PARENT_ZONE_ID"

# Create NS delegation record
aws route53 change-resource-record-sets \
  --hosted-zone-id $PARENT_ZONE_ID \
  --change-batch '{
    "Comment": "Delegate superblocks.oiiro.com to Superblocks account",
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

### Step 3: Verify Delegation
```bash
# Wait 2-3 minutes, then test
dig NS superblocks.oiiro.com @8.8.8.8

# Should return the NS records from Step 1
```

## Validation Steps

### 1. DNS Resolution Test
```bash
# Test subdomain delegation
nslookup superblocks.oiiro.com

# Test agent subdomain (after Superblocks deployment)
nslookup agent.superblocks.oiiro.com
```

### 2. Delegation Chain Test
```bash
# Trace full delegation path
dig +trace agent.superblocks.oiiro.com

# Should show:
# . -> com -> oiiro.com -> superblocks.oiiro.com -> agent.superblocks.oiiro.com
```

### 3. Certificate Validation Test
```bash
# Test HTTPS (after deployment)
curl -I https://agent.superblocks.oiiro.com

# Should return valid certificate
```

## Common Issues and Solutions

### Issue 1: Hosted Zone Not Found
```bash
# Error: Hosted zone for superblocks.oiiro.com not found

# Solution: Deploy Superblocks infrastructure first
cd terraform/superblocks
terraform apply -var-file="../environments/superblocks.tfvars"
```

### Issue 2: Permission Denied
```bash
# Error: User is not authorized to perform route53:ChangeResourceRecordSets

# Solution: Add Route53 permissions to shared services profile
aws iam attach-user-policy \
  --user-name your-user \
  --policy-arn arn:aws:iam::aws:policy/Route53FullAccess
```

### Issue 3: DNS Propagation Delays
```bash
# Error: DNS not resolving immediately

# Solution: Wait 5-15 minutes for global DNS propagation
# Test with different DNS servers
dig @8.8.8.8 superblocks.oiiro.com NS
dig @1.1.1.1 superblocks.oiiro.com NS
```

### Issue 4: Existing Delegation Conflict
```bash
# Error: RRSet already exists

# Solution: Update existing record instead of creating
# Change "Action": "CREATE" to "Action": "UPSERT" in the change batch
```

## DNS Delegation Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Root DNS (.)                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                  .com TLD                                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              oiiro.com (Shared Services)                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  NS Record: superblocks.oiiro.com                      ││
│  │  Points to: ns-xxx.awsdns-xx.com (Superblocks Account) ││
│  └─────────────────┬───────────────────────────────────────┘│
└────────────────────┼────────────────────────────────────────┘
                     │ DNS Delegation
┌────────────────────▼────────────────────────────────────────┐
│           superblocks.oiiro.com (Superblocks Account)       │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  A Record: agent.superblocks.oiiro.com                 ││
│  │  Points to: ALB in Superblocks VPC                     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Security Considerations

### 1. Minimal Cross-Account Access
- Only DNS delegation permissions needed in shared services
- No direct access to Superblocks infrastructure

### 2. DNS Security
- DNSSEC support (if enabled on parent domain)
- Short TTL for faster changes (300 seconds)
- NS record validation

### 3. Certificate Management
- Automatic ACM certificate creation in Superblocks account
- DNS validation within delegated zone
- No certificate sharing across accounts

## Post-Delegation Tasks

### 1. Update Documentation
- Record hosted zone IDs in project documentation
- Update network diagrams with DNS delegation
- Document emergency contact procedures

### 2. Monitoring Setup
- CloudWatch DNS query metrics
- Route53 health checks
- DNS resolution monitoring

### 3. Backup Procedures
- Export Route53 zone configurations
- Document delegation restoration procedures
- Test disaster recovery scenarios

## Rollback Procedures

### Remove Delegation
```bash
# Switch to shared services account
export AWS_PROFILE=oiiro-shared-services

# Remove NS delegation record
aws route53 change-resource-record-sets \
  --hosted-zone-id $PARENT_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
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

### Delete Hosted Zone
```bash
# Switch to Superblocks account
export AWS_PROFILE=superblocks

# Delete all records except NS and SOA
# Then delete hosted zone
aws route53 delete-hosted-zone --id $HOSTED_ZONE_ID
```

## Success Criteria

✅ **DNS Delegation Complete When:**
1. `superblocks.oiiro.com` resolves to Superblocks account NS servers
2. `agent.superblocks.oiiro.com` resolves to ALB IP addresses
3. HTTPS certificate validation succeeds
4. DNS propagation verified globally
5. Superblocks agent accessible via domain

The delegation is successful when you can access the Superblocks agent at `https://agent.superblocks.oiiro.com` with a valid SSL certificate.