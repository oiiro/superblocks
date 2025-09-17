#!/bin/bash

# Workaround script for Superblocks module count error
# This applies resources in stages to avoid the conditional count issue

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Applying Superblocks infrastructure with workaround...${NC}"
echo ""

# Change to terraform directory
cd /Users/rohitiyer/oiiro/superblocks/terraform/superblocks

# Step 1: Initialize Terraform
echo -e "${YELLOW}Step 1: Initializing Terraform...${NC}"
terraform init -upgrade

# Step 2: Apply certificate first
echo -e "${YELLOW}Step 2: Creating self-signed certificate...${NC}"
terraform apply -target=tls_private_key.superblocks -target=tls_self_signed_cert.superblocks -target=aws_acm_certificate.superblocks -var-file="../environments/superblocks.tfvars" -auto-approve

# Step 3: Apply the full configuration
echo -e "${YELLOW}Step 3: Deploying Superblocks module...${NC}"
terraform apply -var-file="../environments/superblocks.tfvars"

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}Get your agent URL with: terraform output agent_url${NC}"