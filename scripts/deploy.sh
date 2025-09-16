#!/bin/bash

# Superblocks Deployment Script
# This script automates the deployment of Superblocks infrastructure

set -e

# Configuration
PROJECT_NAME="superblocks"
TERRAFORM_DIR="terraform"
ENVIRONMENT="${1:-superblocks}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform 1.0 or later."
        exit 1
    fi
    
    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $TERRAFORM_VERSION"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured or invalid."
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to validate environment file
validate_environment() {
    local env_file="$TERRAFORM_DIR/environments/${ENVIRONMENT}.tfvars"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        log_info "Available environments:"
        ls -1 "$TERRAFORM_DIR/environments/"*.tfvars 2>/dev/null | sed 's/.*\///' | sed 's/\.tfvars$//' || echo "No environment files found"
        exit 1
    fi
    
    # Check if agent key is set
    if grep -q "your-superblocks-agent-key-here" "$env_file"; then
        log_error "Please update the superblocks_agent_key in $env_file"
        log_info "Get your agent key from the Superblocks On-Premise Agent Setup Wizard"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Function to deploy VPC
deploy_vpc() {
    log_info "Deploying VPC infrastructure..."
    
    cd "$TERRAFORM_DIR/vpc"
    
    log_info "Initializing Terraform..."
    terraform init
    
    log_info "Planning VPC deployment..."
    terraform plan -var-file="../environments/${ENVIRONMENT}.tfvars" -out=vpc.tfplan
    
    log_info "Applying VPC deployment..."
    terraform apply vpc.tfplan
    
    log_success "VPC deployment completed"
    cd - > /dev/null
}

# Function to deploy Superblocks
deploy_superblocks() {
    log_info "Deploying Superblocks application..."
    
    cd "$TERRAFORM_DIR/superblocks"
    
    log_info "Initializing Terraform..."
    terraform init
    
    log_info "Planning Superblocks deployment..."
    terraform plan -var-file="../environments/${ENVIRONMENT}.tfvars" -out=superblocks.tfplan
    
    log_info "Applying Superblocks deployment..."
    terraform apply superblocks.tfplan
    
    log_success "Superblocks deployment completed"
    
    # Get outputs
    log_info "Retrieving deployment information..."
    APPLICATION_URL=$(terraform output -raw superblocks_url 2>/dev/null || echo "Not available")
    LB_URL=$(terraform output -raw load_balancer_url 2>/dev/null || echo "Not available")
    LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name 2>/dev/null || echo "Not available")
    
    cd - > /dev/null
    
    # Display deployment summary
    echo ""
    log_success "=== DEPLOYMENT SUMMARY ==="
    echo -e "${GREEN}Application URL:${NC} $APPLICATION_URL"
    echo -e "${GREEN}Load Balancer URL:${NC} $LB_URL"
    echo -e "${GREEN}CloudWatch Logs:${NC} $LOG_GROUP"
    echo ""
}

# Function to show deployment status
show_status() {
    log_info "Checking deployment status..."
    
    # Check VPC status
    if [[ -f "$TERRAFORM_DIR/vpc/terraform.tfstate" ]]; then
        log_success "VPC: Deployed"
    else
        log_warning "VPC: Not deployed"
    fi
    
    # Check Superblocks status
    if [[ -f "$TERRAFORM_DIR/superblocks/terraform.tfstate" ]]; then
        log_success "Superblocks: Deployed"
        
        cd "$TERRAFORM_DIR/superblocks"
        if terraform output superblocks_url &> /dev/null; then
            APPLICATION_URL=$(terraform output -raw superblocks_url)
            echo -e "${GREEN}Application URL:${NC} $APPLICATION_URL"
        fi
        cd - > /dev/null
    else
        log_warning "Superblocks: Not deployed"
    fi
}

# Function to destroy infrastructure
destroy_infrastructure() {
    log_warning "This will destroy ALL Superblocks infrastructure!"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Destruction cancelled"
        exit 0
    fi
    
    # Destroy Superblocks first
    if [[ -f "$TERRAFORM_DIR/superblocks/terraform.tfstate" ]]; then
        log_info "Destroying Superblocks application..."
        cd "$TERRAFORM_DIR/superblocks"
        terraform destroy -var-file="../environments/${ENVIRONMENT}.tfvars" -auto-approve
        cd - > /dev/null
        log_success "Superblocks application destroyed"
    fi
    
    # Then destroy VPC
    if [[ -f "$TERRAFORM_DIR/vpc/terraform.tfstate" ]]; then
        log_info "Destroying VPC infrastructure..."
        cd "$TERRAFORM_DIR/vpc"
        terraform destroy -var-file="../environments/${ENVIRONMENT}.tfvars" -auto-approve
        cd - > /dev/null
        log_success "VPC infrastructure destroyed"
    fi
    
    log_success "Infrastructure destruction completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [ENVIRONMENT]"
    echo ""
    echo "Commands:"
    echo "  deploy     Deploy complete infrastructure (default)"
    echo "  vpc        Deploy only VPC infrastructure"
    echo "  app        Deploy only Superblocks application"
    echo "  status     Show deployment status"
    echo "  destroy    Destroy all infrastructure"
    echo "  help       Show this help message"
    echo ""
    echo "Environment:"
    echo "  superblocks     Default environment (default)"
    echo "  production      Production environment"
    echo "  <custom>        Custom environment file"
    echo ""
    echo "Examples:"
    echo "  $0 deploy superblocks     # Deploy with superblocks environment"
    echo "  $0 vpc production         # Deploy only VPC for production"
    echo "  $0 status                 # Show current deployment status"
    echo "  $0 destroy superblocks    # Destroy superblocks environment"
}

# Main script logic
COMMAND="${1:-deploy}"
ENVIRONMENT="${2:-superblocks}"

case $COMMAND in
    deploy)
        check_prerequisites
        validate_environment
        deploy_vpc
        deploy_superblocks
        ;;
    vpc)
        check_prerequisites
        validate_environment
        deploy_vpc
        ;;
    app|superblocks)
        check_prerequisites
        validate_environment
        deploy_superblocks
        ;;
    status)
        show_status
        ;;
    destroy)
        check_prerequisites
        validate_environment
        destroy_infrastructure
        ;;
    help|-h|--help)
        show_usage
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac