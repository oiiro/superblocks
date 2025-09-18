#!/bin/bash
# Deploy Superblocks with environment-specific configuration

set -e

# Default values
ENV="${1:-production}"
ACTION="${2:-apply}"

show_usage() {
    echo "Usage: $0 [environment] [action]"
    echo ""
    echo "Environments:"
    echo "  production  Production deployment (default)"
    echo "  dev         Development deployment"
    echo "  staging     Staging deployment"
    echo ""
    echo "Actions:"
    echo "  apply       Deploy infrastructure (default)"
    echo "  plan        Show deployment plan"
    echo "  destroy     Remove infrastructure"
    echo ""
    echo "Examples:"
    echo "  $0                    # Deploy to production"
    echo "  $0 dev                # Deploy to dev"
    echo "  $0 production plan    # Show production plan"
    echo "  $0 dev destroy        # Destroy dev deployment"
}

if [[ "$ENV" == "help" || "$ENV" == "-h" || "$ENV" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check if environment file exists
ENV_FILE="terraform/environments/${ENV}.tfvars"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: Environment file $ENV_FILE not found"
    echo "   Available environments: $(ls terraform/environments/*.tfvars | xargs -n1 basename | sed 's/.tfvars//' | tr '\n' ' ')"
    exit 1
fi

echo "🚀 Superblocks Deployment"
echo "Environment: $ENV"
echo "Action: $ACTION"
echo ""

# Navigate to terraform directory
cd terraform/superblocks

# Initialize terraform
echo "📦 Initializing Terraform..."
terraform init

case $ACTION in
    plan)
        echo "📋 Generating deployment plan for $ENV..."
        terraform plan -var-file="../environments/${ENV}.tfvars"
        ;;

    apply)
        echo "🔨 Deploying Superblocks to $ENV..."
        terraform apply -var-file="../environments/${ENV}.tfvars"

        echo ""
        echo "✅ Deployment complete!"
        echo ""
        echo "📌 Important outputs:"
        terraform output -json | jq -r '
            "Agent URL: " + .agent_url.value,
            "Load Balancer DNS: " + .load_balancer_dns_name.value,
            "CloudWatch Logs: " + .log_group_name.value
        '
        echo ""
        echo "📝 Route53 Setup Instructions:"
        terraform output -raw route53_instructions
        ;;

    destroy)
        echo "⚠️  This will destroy the Superblocks deployment in $ENV"
        read -p "Are you sure? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            terraform destroy -var-file="../environments/${ENV}.tfvars"
            echo "✅ Infrastructure destroyed"
        else
            echo "Cancelled"
        fi
        ;;

    output)
        terraform output
        ;;

    *)
        echo "❌ Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac