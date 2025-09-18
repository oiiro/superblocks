#!/bin/bash
# Deploy Superblocks HTTP version with Terraform plans

set -e

ACTION="${1:-apply}"
FORCE="${2}"

show_usage() {
    echo "Usage: $0 [apply|destroy] [--force]"
    echo ""
    echo "Commands:"
    echo "  apply    Deploy Superblocks HTTP version (default)"
    echo "  destroy  Remove Superblocks HTTP deployment"
    echo ""
    echo "Options:"
    echo "  --force  Skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0                  # Deploy with confirmation"
    echo "  $0 apply --force    # Deploy without confirmation"
    echo "  $0 destroy          # Destroy with confirmation"
    echo "  $0 destroy --force  # Destroy without confirmation"
}

if [[ "$ACTION" == "help" || "$ACTION" == "-h" || "$ACTION" == "--help" ]]; then
    show_usage
    exit 0
fi

echo "🚀 Superblocks HTTP Deployment Script"
echo "Action: $ACTION"

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

case $ACTION in
    apply)
        # Deploy VPC if needed
        if [ ! -f "terraform/vpc/terraform.tfstate" ]; then
            echo "📡 Deploying VPC first..."
            cd terraform/vpc
            terraform init
            echo "📋 Generating VPC plan..."
            terraform plan -var-file="../environments/superblocks.tfvars" -out=vpc.tfplan
            
            if [[ "$FORCE" != "--force" ]]; then
                echo ""
                read -p "Deploy VPC? (y/N): " -r
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "VPC deployment cancelled"
                    exit 0
                fi
            fi
            
            terraform apply vpc.tfplan
            echo "✅ VPC deployed successfully"
            cd ../..
        fi

        # Deploy Superblocks HTTP
        echo "🌐 Deploying Superblocks (HTTP)..."
        cd terraform/superblocks-simple
        terraform init
        
        echo "📋 Generating Superblocks HTTP plan..."
        terraform plan -var-file="../environments/superblocks.tfvars" -out=superblocks-simple.tfplan
        
        if [[ "$FORCE" != "--force" ]]; then
            echo ""
            read -p "Deploy Superblocks HTTP? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Deployment cancelled"
                exit 0
            fi
        fi
        
        terraform apply superblocks-simple.tfplan
        
        echo ""
        echo "✅ Deployment complete!"
        echo "🔗 Agent URL: $(terraform output -raw agent_url)"
        echo "📋 Add this URL to your Superblocks dashboard"
        ;;
        
    destroy)
        echo "⚠️  This will destroy the Superblocks HTTP deployment"
        
        if [[ "$FORCE" != "--force" ]]; then
            echo ""
            read -p "Are you sure you want to destroy the deployment? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Destruction cancelled"
                exit 0
            fi
        fi
        
        # Destroy Superblocks first
        if [ -f "terraform/superblocks-simple/terraform.tfstate" ]; then
            echo "🗑️  Destroying Superblocks HTTP deployment..."
            cd terraform/superblocks-simple
            terraform init
            
            echo "📋 Generating destruction plan..."
            terraform plan -destroy -var-file="../environments/superblocks.tfvars" -out=superblocks-simple-destroy.tfplan
            terraform apply superblocks-simple-destroy.tfplan
            
            echo "✅ Superblocks HTTP deployment destroyed"
            cd ../..
        else
            echo "ℹ️  No Superblocks HTTP deployment found"
        fi
        
        # Ask about VPC destruction
        if [ -f "terraform/vpc/terraform.tfstate" ]; then
            if [[ "$FORCE" == "--force" ]]; then
                DESTROY_VPC="y"
            else
                echo ""
                read -p "Also destroy VPC? (y/N): " -r
                DESTROY_VPC=$REPLY
            fi
            
            if [[ $DESTROY_VPC =~ ^[Yy]$ ]]; then
                echo "🗑️  Destroying VPC..."
                cd terraform/vpc
                terraform init
                
                echo "📋 Generating VPC destruction plan..."
                terraform plan -destroy -var-file="../environments/superblocks.tfvars" -out=vpc-destroy.tfplan
                terraform apply vpc-destroy.tfplan
                
                echo "✅ VPC destroyed"
                cd ../..
            fi
        fi
        
        echo "✅ Destruction complete!"
        ;;
        
    *)
        echo "❌ Error: Unknown action '$ACTION'"
        show_usage
        exit 1
        ;;
esac