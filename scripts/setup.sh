#!/bin/bash
#
# Master Setup Script
# Executes all steps sequentially: prerequisites validation, Terraform initialization,
# service account key generation, infrastructure provisioning, and Jenkins VM configuration
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
SKIP_PREREQUISITES=false
SKIP_SA_KEY=false
AUTO_APPROVE=false
PLAN_ONLY=false

print_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}║     GCP GKE Jenkins Infrastructure - Master Setup Script      ║${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
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
    echo "  --skip-prerequisites    Skip prerequisites validation"
    echo "  --skip-sa-key          Skip service account key generation"
    echo "  --auto-approve         Auto-approve Terraform apply"
    echo "  --plan-only            Only run Terraform plan (no apply)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GCP_PROJECT_ID         GCP Project ID"
    echo "  GCP_REGION             GCP Region"
    echo "  GCP_ZONE               GCP Zone"
    echo "  GKE_CLUSTER_NAME       GKE Cluster name"
    echo ""
    echo "Example:"
    echo "  source .env && ./scripts/setup.sh --auto-approve"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-prerequisites)
            SKIP_PREREQUISITES=true
            shift
            ;;
        --skip-sa-key)
            SKIP_SA_KEY=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --plan-only)
            PLAN_ONLY=true
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
    print_info "Loading environment variables from .env"
    source .env
else
    print_warning ".env file not found. Using default values or existing environment variables."
    print_info "Copy .env.example to .env and configure before running."
fi

# Display configuration
print_info "Configuration:"
echo "  Project ID:     ${GCP_PROJECT_ID:-speedy-insight-483010-m3}"
echo "  Region:         ${GCP_REGION:-us-central1}"
echo "  Zone:           ${GCP_ZONE:-us-central1-a}"
echo "  Cluster Name:   ${GKE_CLUSTER_NAME:-autopilot-cluster-1}"
echo "  Jenkins VM:     ${JENKINS_VM_NAME:-jenkins-server}"
echo ""

# ============================================================================
# STEP 1: Prerequisites Validation
# ============================================================================
if [ "$SKIP_PREREQUISITES" = false ]; then
    print_step "1" "Prerequisites Validation"
    
    if [ -x "$SCRIPT_DIR/validate-prerequisites.sh" ]; then
        bash "$SCRIPT_DIR/validate-prerequisites.sh" || {
            print_error "Prerequisites validation failed. Please fix the issues and try again."
            exit 1
        }
    else
        print_warning "Prerequisites validation script not found. Skipping..."
    fi
else
    print_step "1" "Prerequisites Validation (SKIPPED)"
fi

# ============================================================================
# STEP 2: Enable Required GCP APIs
# ============================================================================
print_step "2" "Enable Required GCP APIs"

PROJECT_ID="${GCP_PROJECT_ID:-speedy-insight-483010-m3}"

print_info "Enabling required APIs for project: $PROJECT_ID"

REQUIRED_APIS=(
    "compute.googleapis.com"
    "container.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "servicenetworking.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    print_info "Enabling API: $api"
    gcloud services enable "$api" --project="$PROJECT_ID" --quiet 2>/dev/null || {
        print_warning "Could not enable $api (may already be enabled or require permissions)"
    }
done

print_success "API enablement complete"

# ============================================================================
# STEP 3: Service Account Key Generation (Optional)
# ============================================================================
if [ "$SKIP_SA_KEY" = false ]; then
    print_step "3" "Service Account Key Generation"
    
    # Check if key already exists
    KEY_PATH="${LOCAL_SA_KEY_PATH:-./keys/service-account-key.json}"
    if [ -f "$KEY_PATH" ]; then
        print_warning "Service account key already exists at: $KEY_PATH"
        read -p "Do you want to generate a new key? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "$SCRIPT_DIR/generate-service-account-key.sh"
        else
            print_info "Using existing key"
        fi
    else
        if [ -x "$SCRIPT_DIR/generate-service-account-key.sh" ]; then
            bash "$SCRIPT_DIR/generate-service-account-key.sh"
        else
            print_warning "Service account key generation script not found. Terraform will create the key."
        fi
    fi
else
    print_step "3" "Service Account Key Generation (SKIPPED)"
fi

# ============================================================================
# STEP 4: Terraform Initialization
# ============================================================================
print_step "4" "Terraform Initialization"

print_info "Initializing Terraform..."
terraform init -upgrade

print_success "Terraform initialized"

# ============================================================================
# STEP 5: Create terraform.tfvars
# ============================================================================
print_step "5" "Configure Terraform Variables"

if [ ! -f "terraform.tfvars" ]; then
    print_info "Creating terraform.tfvars from environment variables..."
    
    cat > terraform.tfvars << EOF
# Auto-generated terraform.tfvars
# Generated on: $(date)

project_id = "${GCP_PROJECT_ID:-speedy-insight-483010-m3}"
region     = "${GCP_REGION:-us-central1}"
zone       = "${GCP_ZONE:-us-central1-a}"

# GKE Configuration
gke_cluster_name      = "${GKE_CLUSTER_NAME:-autopilot-cluster-1}"
gke_node_count        = ${GKE_NODE_COUNT:-2}
gke_min_node_count    = ${GKE_MIN_NODE_COUNT:-1}
gke_max_node_count    = ${GKE_MAX_NODE_COUNT:-5}
gke_node_machine_type = "${GKE_NODE_MACHINE_TYPE:-e2-medium}"
gke_node_disk_size_gb = ${GKE_NODE_DISK_SIZE_GB:-50}
gke_preemptible_nodes = ${GKE_PREEMPTIBLE_NODES:-true}

# Jenkins Configuration
jenkins_vm_name      = "${JENKINS_VM_NAME:-jenkins-server}"
jenkins_machine_type = "${JENKINS_MACHINE_TYPE:-e2-medium}"
jenkins_disk_size_gb = ${JENKINS_DISK_SIZE_GB:-50}
jenkins_preemptible  = ${JENKINS_PREEMPTIBLE:-false}
jenkins_http_port    = ${JENKINS_HTTP_PORT:-8080}

# Service Account
service_account_name     = "${SERVICE_ACCOUNT_NAME:-gke-jenkins-sa}"
service_account_key_path = "${SERVICE_ACCOUNT_KEY_PATH:-/var/lib/jenkins/keys/speedy-insight-483010-m3-e631e1327727.json}"

# Python
python_version = "${PYTHON_VERSION:-3.11}"

# Labels
environment = "${ENVIRONMENT:-development}"
team        = "${TEAM:-devops}"
application = "${APPLICATION:-jenkins-cicd}"
EOF

    print_success "terraform.tfvars created"
else
    print_info "terraform.tfvars already exists"
fi

# ============================================================================
# STEP 6: Terraform Plan
# ============================================================================
print_step "6" "Terraform Plan"

print_info "Running Terraform plan..."
terraform plan -out=tfplan

print_success "Terraform plan complete"

if [ "$PLAN_ONLY" = true ]; then
    print_info "Plan-only mode. Exiting without applying."
    print_success "Setup complete (plan only)"
    exit 0
fi

# ============================================================================
# STEP 7: Terraform Apply
# ============================================================================
print_step "7" "Terraform Apply"

if [ "$AUTO_APPROVE" = true ]; then
    print_info "Auto-approve enabled. Applying Terraform plan..."
    terraform apply tfplan
else
    print_info "Review the plan above and confirm to proceed."
    read -p "Do you want to apply this plan? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
    else
        print_warning "Terraform apply cancelled"
        exit 0
    fi
fi

print_success "Terraform apply complete"

# ============================================================================
# STEP 8: Post-Deployment Configuration
# ============================================================================
print_step "8" "Post-Deployment Configuration"

# Get outputs
print_info "Retrieving deployment outputs..."

GKE_CLUSTER=$(terraform output -raw gke_cluster_name 2>/dev/null || echo "")
GKE_ZONE=$(terraform output -raw gke_cluster_location 2>/dev/null || echo "")
JENKINS_IP=$(terraform output -raw jenkins_external_ip 2>/dev/null || echo "")
JENKINS_URL=$(terraform output -raw jenkins_url 2>/dev/null || echo "")

# Configure kubectl
if [ -n "$GKE_CLUSTER" ] && [ -n "$GKE_ZONE" ]; then
    print_info "Configuring kubectl for GKE cluster..."
    gcloud container clusters get-credentials "$GKE_CLUSTER" \
        --zone "$GKE_ZONE" \
        --project "$PROJECT_ID" || {
        print_warning "Could not configure kubectl. You may need to do this manually."
    }
fi

# ============================================================================
# STEP 9: Verification
# ============================================================================
print_step "9" "Verification"

print_info "Running verification checks..."

# Verify GKE cluster
if [ -n "$GKE_CLUSTER" ]; then
    print_info "Checking GKE cluster status..."
    if kubectl cluster-info &>/dev/null; then
        print_success "GKE cluster is accessible"
        kubectl get nodes
    else
        print_warning "Could not connect to GKE cluster"
    fi
fi

# Verify Jenkins VM
if [ -n "$JENKINS_IP" ]; then
    print_info "Checking Jenkins VM accessibility..."
    if curl -s --connect-timeout 10 "http://$JENKINS_IP:8080" &>/dev/null; then
        print_success "Jenkins is accessible at: $JENKINS_URL"
    else
        print_warning "Jenkins may still be starting up. Check again in a few minutes."
    fi
fi

# ============================================================================
# Summary
# ============================================================================
print_step "10" "Deployment Summary"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    DEPLOYMENT COMPLETE                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

terraform output connection_info 2>/dev/null || {
    echo "GKE Cluster: $GKE_CLUSTER"
    echo "Jenkins URL: $JENKINS_URL"
}

echo ""
echo "Next Steps:"
echo "  1. Wait 5-10 minutes for Jenkins to fully initialize"
echo "  2. Access Jenkins at: $JENKINS_URL"
echo "  3. Get initial admin password:"
echo "     gcloud compute ssh jenkins-server --zone=$GKE_ZONE --command='sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
echo "  4. Configure Jenkins plugins and pipelines"
echo ""

print_success "Master setup complete!"
