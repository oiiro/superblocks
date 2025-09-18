#!/bin/bash
# Setup AWS Secrets Manager for Superblocks Agent Key

set -e

# Configuration
SECRET_NAME="${1:-superblocks-agent-key}"
AGENT_KEY="${2}"
REGION="${3:-us-east-1}"

show_usage() {
    echo "Usage: $0 [secret-name] [agent-key] [region]"
    echo ""
    echo "Parameters:"
    echo "  secret-name   Name for the secret (default: superblocks-agent-key)"
    echo "  agent-key     Your Superblocks agent key (starts with sb_agent_)"
    echo "  region        AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0 superblocks-agent-key sb_agent_xxxxx us-east-1"
    echo "  $0 my-agent-key sb_agent_xxxxx"
    echo ""
    echo "Get your agent key from: https://app.superblocks.com → Settings → On-Premise Agent"
}

if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

if [[ -z "$AGENT_KEY" ]]; then
    echo "❌ Error: Agent key is required"
    echo ""
    show_usage
    exit 1
fi

if [[ ! "$AGENT_KEY" =~ ^sb_agent_ ]]; then
    echo "❌ Error: Agent key should start with 'sb_agent_'"
    exit 1
fi

echo "🔐 Setting up Secrets Manager for Superblocks Agent"
echo "Secret Name: $SECRET_NAME"
echo "Region: $REGION"
echo ""

# Check if secret already exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "⚠️  Secret '$SECRET_NAME' already exists"
    read -p "Update existing secret? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi

    # Update existing secret
    SECRET_ARN=$(aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "$AGENT_KEY" \
        --region "$REGION" \
        --query 'ARN' \
        --output text)

    echo "✅ Secret updated successfully"
else
    # Create new secret
    SECRET_ARN=$(aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "Superblocks agent key for authentication" \
        --secret-string "$AGENT_KEY" \
        --region "$REGION" \
        --query 'ARN' \
        --output text)

    echo "✅ Secret created successfully"
fi

echo ""
echo "📝 Configuration for terraform.tfvars:"
echo ""
echo "# Use Secrets Manager (recommended)"
echo "agent_key_secret_arn = \"$SECRET_ARN\""
echo "superblocks_agent_key = \"\"  # Leave empty when using Secrets Manager"
echo ""
echo "🔗 Secret ARN: $SECRET_ARN"
echo ""
echo "Next steps:"
echo "1. Update your terraform.tfvars with the configuration above"
echo "2. Run: terraform plan"
echo "3. Run: terraform apply"