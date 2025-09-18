#!/bin/bash
# Cleanup all Superblocks deployments

set -e

echo "🧹 Cleaning up Superblocks deployments..."

# Function to destroy if state exists
destroy_if_exists() {
    local dir=$1
    local name=$2
    
    if [ -f "$dir/terraform.tfstate" ]; then
        echo "🗑️  Destroying $name..."
        cd "$dir"
        terraform destroy -var-file="../environments/superblocks.tfvars" -auto-approve
        cd - > /dev/null
    else
        echo "ℹ️  No $name deployment found"
    fi
}

# Destroy Superblocks deployments first
destroy_if_exists "terraform/superblocks-simple" "HTTP deployment"
destroy_if_exists "terraform/superblocks-simple-https" "HTTPS deployment"
destroy_if_exists "terraform/superblocks" "Official module deployment"

# Then destroy VPC
destroy_if_exists "terraform/vpc" "VPC"

echo "✅ Cleanup complete!"