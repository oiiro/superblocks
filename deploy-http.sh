#!/bin/bash
# Deploy Superblocks HTTP version

set -e

echo "🚀 Deploying Superblocks (HTTP version)..."

# Check prerequisites
if [ ! -f "terraform/environments/superblocks.tfvars" ]; then
    echo "❌ Error: terraform/environments/superblocks.tfvars not found"
    echo "   Please update your agent key first"
    exit 1
fi

# Check agent key
if grep -q "sb_agent_your-actual-key-here" terraform/environments/superblocks.tfvars; then
    echo "❌ Error: Please update your Superblocks agent key in terraform/environments/superblocks.tfvars"
    exit 1
fi

# Deploy VPC if needed
if [ ! -f "terraform/vpc/terraform.tfstate" ]; then
    echo "📡 Deploying VPC first..."
    cd terraform/vpc
    terraform init
    terraform apply -var-file="../environments/superblocks.tfvars" -auto-approve
    cd ../..
fi

# Deploy Superblocks HTTP
echo "🌐 Deploying Superblocks (HTTP)..."
cd terraform/superblocks-simple
terraform init
terraform apply -var-file="../environments/superblocks.tfvars"

echo "✅ Deployment complete!"
echo "🔗 Agent URL: $(terraform output -raw agent_url)"