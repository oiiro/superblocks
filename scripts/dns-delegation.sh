#!/bin/bash

# DNS Delegation Script for Superblocks
# This script helps configure cross-account DNS delegation for agent.superblocks.oiiro.com

set -e

# Configuration
SUPERBLOCKS_DOMAIN="superblocks.oiiro.com"
PARENT_DOMAIN="oiiro.com"
SUPERBLOCKS_PROFILE="${1:-superblocks}"
SHARED_SERVICES_PROFILE="${2:-oiiro-shared-services}"

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [superblocks-profile] [shared-services-profile]"
    echo ""
    echo "This script configures DNS delegation for agent.superblocks.oiiro.com"
    echo ""
    echo "Parameters:"
    echo "  superblocks-profile      AWS profile for Superblocks account (default: superblocks)"
    echo "  shared-services-profile  AWS profile for shared services account (default: oiiro-shared-services)"
    echo ""
    echo "Prerequisites:"
    echo "  1. Superblocks infrastructure deployed with hosted zone created"
    echo "  2. AWS CLI configured with both profiles"
    echo "  3. Appropriate permissions in both accounts"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use default profiles"
    echo "  $0 superblocks oiiro-shared-services # Explicit profiles"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed."
        exit 1
    fi
    
    # Check Superblocks profile
    if ! aws configure list --profile "$SUPERBLOCKS_PROFILE" &> /dev/null; then
        log_error "AWS profile '$SUPERBLOCKS_PROFILE' not found."
        log_info "Configure with: aws configure --profile $SUPERBLOCKS_PROFILE"
        exit 1
    fi
    
    # Check shared services profile
    if ! aws configure list --profile "$SHARED_SERVICES_PROFILE" &> /dev/null; then
        log_error "AWS profile '$SHARED_SERVICES_PROFILE' not found."
        log_info "Configure with: aws configure --profile $SHARED_SERVICES_PROFILE"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to get hosted zone information
get_superblocks_hosted_zone() {
    log_info "Finding Superblocks hosted zone..."
    
    HOSTED_ZONE_ID=$(AWS_PROFILE="$SUPERBLOCKS_PROFILE" aws route53 list-hosted-zones \
        --query "HostedZones[?Name=='${SUPERBLOCKS_DOMAIN}.'].Id" \
        --output text | sed 's|/hostedzone/||')
    
    if [[ -z "$HOSTED_ZONE_ID" || "$HOSTED_ZONE_ID" == "None" ]]; then
        log_error "Hosted zone for $SUPERBLOCKS_DOMAIN not found in Superblocks account"
        log_info "Please deploy Superblocks infrastructure first to create the hosted zone"
        exit 1
    fi
    
    log_success "Found hosted zone: $HOSTED_ZONE_ID"
    
    # Get name servers
    NAME_SERVERS=$(AWS_PROFILE="$SUPERBLOCKS_PROFILE" aws route53 get-hosted-zone \
        --id "$HOSTED_ZONE_ID" \
        --query 'DelegationSet.NameServers' \
        --output json)
    
    if [[ -z "$NAME_SERVERS" || "$NAME_SERVERS" == "null" ]]; then
        log_error "Failed to retrieve name servers for hosted zone"
        exit 1
    fi
    
    log_success "Retrieved name servers"
    echo "$NAME_SERVERS" | jq -r '.[]' | while read -r ns; do
        log_info "  $ns"
    done
}

# Function to get parent hosted zone
get_parent_hosted_zone() {
    log_info "Finding parent hosted zone for $PARENT_DOMAIN..."
    
    PARENT_ZONE_ID=$(AWS_PROFILE="$SHARED_SERVICES_PROFILE" aws route53 list-hosted-zones \
        --query "HostedZones[?Name=='${PARENT_DOMAIN}.'].Id" \
        --output text | sed 's|/hostedzone/||')
    
    if [[ -z "$PARENT_ZONE_ID" || "$PARENT_ZONE_ID" == "None" ]]; then
        log_error "Hosted zone for $PARENT_DOMAIN not found in shared services account"
        log_info "Please ensure the oiiro.com hosted zone exists"
        exit 1
    fi
    
    log_success "Found parent hosted zone: $PARENT_ZONE_ID"
}

# Function to check if delegation already exists
check_existing_delegation() {
    log_info "Checking for existing delegation..."
    
    EXISTING_RECORD=$(AWS_PROFILE="$SHARED_SERVICES_PROFILE" aws route53 list-resource-record-sets \
        --hosted-zone-id "$PARENT_ZONE_ID" \
        --query "ResourceRecordSets[?Name=='${SUPERBLOCKS_DOMAIN}.' && Type=='NS']" \
        --output json)
    
    if [[ "$EXISTING_RECORD" != "[]" ]]; then
        log_warning "NS record for $SUPERBLOCKS_DOMAIN already exists in parent zone"
        echo "$EXISTING_RECORD" | jq '.[0].ResourceRecords[].Value' | sed 's/\"//g' | while read -r ns; do
            log_info "  Existing NS: $ns"
        done
        
        read -p "Do you want to update the existing delegation? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Delegation cancelled"
            exit 0
        fi
        UPDATE_DELEGATION=true
    else
        log_info "No existing delegation found"
        UPDATE_DELEGATION=false
    fi
}

# Function to create delegation record
create_delegation() {
    log_info "Creating DNS delegation record..."
    
    # Convert name servers to proper format
    RESOURCE_RECORDS=$(echo "$NAME_SERVERS" | jq -r '.[] | {Value: .}' | jq -s '.')
    
    # Determine action
    ACTION="CREATE"
    if [[ "$UPDATE_DELEGATION" == "true" ]]; then
        ACTION="UPSERT"
    fi
    
    # Create change batch
    CHANGE_BATCH=$(cat <<EOF
{
    "Comment": "Delegate ${SUPERBLOCKS_DOMAIN} to Superblocks account",
    "Changes": [{
        "Action": "$ACTION",
        "ResourceRecordSet": {
            "Name": "${SUPERBLOCKS_DOMAIN}",
            "Type": "NS",
            "TTL": 300,
            "ResourceRecords": $RESOURCE_RECORDS
        }
    }]
}
EOF
)
    
    log_info "Submitting delegation change..."
    CHANGE_ID=$(AWS_PROFILE="$SHARED_SERVICES_PROFILE" aws route53 change-resource-record-sets \
        --hosted-zone-id "$PARENT_ZONE_ID" \
        --change-batch "$CHANGE_BATCH" \
        --query 'ChangeInfo.Id' \
        --output text)
    
    if [[ -z "$CHANGE_ID" ]]; then
        log_error "Failed to create delegation record"
        exit 1
    fi
    
    log_success "Delegation change submitted: $CHANGE_ID"
}

# Function to wait for change propagation
wait_for_propagation() {
    log_info "Waiting for DNS change to propagate..."
    
    AWS_PROFILE="$SHARED_SERVICES_PROFILE" aws route53 wait resource-record-sets-changed \
        --id "$CHANGE_ID"
    
    log_success "DNS change propagated successfully"
}

# Function to verify delegation
verify_delegation() {
    log_info "Verifying DNS delegation..."
    
    # Wait a bit for DNS propagation
    sleep 10
    
    # Test delegation
    log_info "Testing delegation with dig..."
    if command -v dig &> /dev/null; then
        RESOLVED_NS=$(dig +short NS "$SUPERBLOCKS_DOMAIN" @8.8.8.8 | sort)
        EXPECTED_NS=$(echo "$NAME_SERVERS" | jq -r '.[]' | sort)
        
        if [[ "$RESOLVED_NS" == "$EXPECTED_NS" ]]; then
            log_success "DNS delegation verified successfully"
        else
            log_warning "DNS delegation may not be fully propagated yet"
            log_info "Expected NS records:"
            echo "$EXPECTED_NS" | while read -r ns; do
                log_info "  $ns"
            done
            log_info "Resolved NS records:"
            echo "$RESOLVED_NS" | while read -r ns; do
                log_info "  $ns"
            done
        fi
    else
        log_warning "dig command not available, skipping verification"
    fi
    
    # Test agent subdomain resolution
    log_info "Testing agent subdomain resolution..."
    if nslookup "agent.$SUPERBLOCKS_DOMAIN" &> /dev/null; then
        log_success "agent.$SUPERBLOCKS_DOMAIN resolves successfully"
    else
        log_warning "agent.$SUPERBLOCKS_DOMAIN not yet resolvable (may need more time)"
    fi
}

# Function to show completion summary
show_summary() {
    echo ""
    log_success "=== DNS DELEGATION COMPLETED ==="
    echo -e "${GREEN}Domain:${NC} $SUPERBLOCKS_DOMAIN"
    echo -e "${GREEN}Parent Zone:${NC} $PARENT_DOMAIN"
    echo -e "${GREEN}Superblocks Hosted Zone ID:${NC} $HOSTED_ZONE_ID"
    echo -e "${GREEN}Parent Hosted Zone ID:${NC} $PARENT_ZONE_ID"
    echo ""
    echo -e "${GREEN}Name Servers Delegated:${NC}"
    echo "$NAME_SERVERS" | jq -r '.[]' | while read -r ns; do
        echo "  $ns"
    done
    echo ""
    log_info "Next Steps:"
    echo "  1. Wait 5-10 minutes for full DNS propagation"
    echo "  2. Test resolution: nslookup agent.$SUPERBLOCKS_DOMAIN"
    echo "  3. Deploy Superblocks application if not already done"
    echo "  4. Access agent at: https://agent.$SUPERBLOCKS_DOMAIN"
    echo ""
}

# Main script logic
case "${1:-help}" in
    help|-h|--help)
        show_usage
        exit 0
        ;;
    *)
        log_info "Starting DNS delegation configuration..."
        log_info "Superblocks profile: $SUPERBLOCKS_PROFILE"
        log_info "Shared services profile: $SHARED_SERVICES_PROFILE"
        echo ""
        
        check_prerequisites
        get_superblocks_hosted_zone
        get_parent_hosted_zone
        check_existing_delegation
        create_delegation
        wait_for_propagation
        verify_delegation
        show_summary
        ;;
esac