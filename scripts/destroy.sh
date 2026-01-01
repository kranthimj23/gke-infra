#!/bin/bash
#
# Cleanup/Destroy Script
# Destroys all provisioned GCP resources
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
AUTO_APPROVE=false
CLEANUP_SA_KEYS=false
CLEANUP_LOCAL_FILES=false

print_banner() {
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║     GCP GKE Jenkins Infrastructure - DESTROY Script           ║${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║     WARNING: This will destroy ALL provisioned resources!     ║${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  STEP $1: $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --auto-approve         Auto-approve Terraform destroy (DANGEROUS)"
    echo "  --cleanup-sa-keys      Also delete service account keys from GCP"
    echo "  --cleanup-local        Also delete local files (keys, tfstate, etc.)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Example:"
    echo "  ./scripts/destroy.sh                    # Interactive mode"
    echo "  ./scripts/destroy.sh --auto-approve    # Non-interactive (DANGEROUS)"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --cleanup-sa-keys)
            CLEANUP_SA_KEYS=true
            shift
            ;;
        --cleanup-local)
            CLEANUP_LOCAL_FILES=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Change to project directory
cd "$PROJECT_DIR"

print_banner

# Load environment variables if .env exists
if [ -f ".env" ]; then
    source .env
fi

PROJECT_ID="${GCP_PROJECT_ID:-speedy-insight-483010-m3}"

# ============================================================================
# Confirmation
# ============================================================================
if [ "$AUTO_APPROVE" = false ]; then
    echo -e "${RED}WARNING: This script will destroy the following resources:${NC}"
    echo ""
    echo "  - GKE Cluster and all node pools"
    echo "  - Jenkins VM and associated disks"
    echo "  - VPC Network, subnets, and firewall rules"
    echo "  - Cloud NAT and Cloud Router"
    echo "  - Service accounts (IAM bindings will be removed)"
    echo ""
    echo -e "${YELLOW}This action is IRREVERSIBLE!${NC}"
    echo ""
    
    read -p "Type 'DESTROY' to confirm: " confirmation
    if [ "$confirmation" != "DESTROY" ]; then
        print_info "Destruction cancelled"
        exit 0
    fi
    
    echo ""
    read -p "Are you absolutely sure? (yes/no): " final_confirm
    if [ "$final_confirm" != "yes" ]; then
        print_info "Destruction cancelled"
        exit 0
    fi
fi

# ============================================================================
# STEP 1: Pre-Destroy Checks
# ============================================================================
print_step "1" "Pre-Destroy Checks"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ] && [ ! -d ".terraform" ]; then
    print_warning "No Terraform state found. Nothing to destroy."
    exit 0
fi

# Check Terraform is initialized
if [ ! -d ".terraform" ]; then
    print_info "Initializing Terraform..."
    terraform init
fi

# Show what will be destroyed
print_info "Resources to be destroyed:"
terraform state list 2>/dev/null || print_warning "Could not list resources"

# ============================================================================
# STEP 2: Remove kubectl context
# ============================================================================
print_step "2" "Remove kubectl Context"

GKE_CLUSTER=$(terraform output -raw gke_cluster_name 2>/dev/null || echo "")
GKE_ZONE=$(terraform output -raw gke_cluster_location 2>/dev/null || echo "")

if [ -n "$GKE_CLUSTER" ]; then
    print_info "Removing kubectl context for cluster: $GKE_CLUSTER"
    kubectl config delete-context "gke_${PROJECT_ID}_${GKE_ZONE}_${GKE_CLUSTER}" 2>/dev/null || true
    kubectl config delete-cluster "gke_${PROJECT_ID}_${GKE_ZONE}_${GKE_CLUSTER}" 2>/dev/null || true
    print_success "kubectl context removed"
else
    print_info "No GKE cluster context to remove"
fi

# ============================================================================
# STEP 3: Terraform Destroy
# ============================================================================
print_step "3" "Terraform Destroy"

print_info "Running Terraform destroy..."

if [ "$AUTO_APPROVE" = true ]; then
    terraform destroy -auto-approve
else
    terraform destroy
fi

print_success "Terraform destroy complete"

# ============================================================================
# STEP 4: Cleanup Service Account Keys (Optional)
# ============================================================================
if [ "$CLEANUP_SA_KEYS" = true ]; then
    print_step "4" "Cleanup Service Account Keys"
    
    SA_NAME="${SERVICE_ACCOUNT_NAME:-gke-jenkins-sa}"
    
    for suffix in "gke" "jenkins"; do
        SA_EMAIL="${SA_NAME}-${suffix}@${PROJECT_ID}.iam.gserviceaccount.com"
        
        print_info "Checking for service account: $SA_EMAIL"
        
        if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
            print_info "Deleting all keys for: $SA_EMAIL"
            
            # List and delete all user-managed keys
            KEYS=$(gcloud iam service-accounts keys list \
                --iam-account="$SA_EMAIL" \
                --project="$PROJECT_ID" \
                --format="value(name)" \
                --filter="keyType=USER_MANAGED" 2>/dev/null || echo "")
            
            for key in $KEYS; do
                KEY_ID=$(basename "$key")
                print_info "Deleting key: $KEY_ID"
                gcloud iam service-accounts keys delete "$KEY_ID" \
                    --iam-account="$SA_EMAIL" \
                    --project="$PROJECT_ID" \
                    --quiet 2>/dev/null || true
            done
            
            # Optionally delete the service account itself
            read -p "Delete service account $SA_EMAIL? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                gcloud iam service-accounts delete "$SA_EMAIL" \
                    --project="$PROJECT_ID" \
                    --quiet 2>/dev/null || true
                print_success "Service account deleted: $SA_EMAIL"
            fi
        else
            print_info "Service account not found: $SA_EMAIL"
        fi
    done
else
    print_step "4" "Cleanup Service Account Keys (SKIPPED)"
fi

# ============================================================================
# STEP 5: Cleanup Local Files (Optional)
# ============================================================================
if [ "$CLEANUP_LOCAL_FILES" = true ]; then
    print_step "5" "Cleanup Local Files"
    
    # Remove Terraform files
    print_info "Removing Terraform state files..."
    rm -f terraform.tfstate terraform.tfstate.backup tfplan 2>/dev/null || true
    rm -rf .terraform 2>/dev/null || true
    rm -f .terraform.lock.hcl 2>/dev/null || true
    
    # Remove generated files
    print_info "Removing generated files..."
    rm -f terraform.tfvars 2>/dev/null || true
    rm -rf keys/ 2>/dev/null || true
    
    print_success "Local files cleaned up"
else
    print_step "5" "Cleanup Local Files (SKIPPED)"
    print_info "Local files preserved. To clean up manually:"
    echo "  rm -f terraform.tfstate terraform.tfstate.backup tfplan"
    echo "  rm -rf .terraform"
    echo "  rm -f terraform.tfvars"
    echo "  rm -rf keys/"
fi

# ============================================================================
# Summary
# ============================================================================
print_step "6" "Cleanup Summary"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    CLEANUP COMPLETE                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Resources destroyed:"
echo "  - GKE Cluster"
echo "  - Jenkins VM"
echo "  - VPC Network and subnets"
echo "  - Firewall rules"
echo "  - Cloud NAT and Router"
echo "  - Service accounts and IAM bindings"
echo ""

if [ "$CLEANUP_LOCAL_FILES" = false ]; then
    echo "Local files preserved:"
    echo "  - terraform.tfstate (if exists)"
    echo "  - .terraform directory"
    echo "  - keys/ directory"
    echo ""
fi

print_success "All GCP resources have been destroyed!"
