#!/bin/bash
#
# Verification Script
# Verifies the infrastructure deployment is functional
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

# Counters
PASSED=0
FAILED=0
WARNINGS=0

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     GCP GKE Jenkins Infrastructure - Verification Script      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

check_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Change to project directory
cd "$PROJECT_DIR"

print_header

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

PROJECT_ID="${GCP_PROJECT_ID:-speedy-insight-483010-m3}"
ZONE="${GCP_ZONE:-us-central1-a}"

# Get Terraform outputs
if [ -f "terraform.tfstate" ]; then
    GKE_CLUSTER=$(terraform output -raw gke_cluster_name 2>/dev/null || echo "")
    GKE_ZONE=$(terraform output -raw gke_cluster_location 2>/dev/null || echo "")
    JENKINS_IP=$(terraform output -raw jenkins_external_ip 2>/dev/null || echo "")
    JENKINS_URL=$(terraform output -raw jenkins_url 2>/dev/null || echo "")
    JENKINS_VM=$(terraform output -raw jenkins_vm_name 2>/dev/null || echo "")
else
    check_warn "No Terraform state found. Using environment variables."
    GKE_CLUSTER="${GKE_CLUSTER_NAME:-autopilot-cluster-1}"
    GKE_ZONE="$ZONE"
    JENKINS_VM="${JENKINS_VM_NAME:-jenkins-server}"
fi

# ============================================================================
# GCP Authentication Verification
# ============================================================================
print_section "GCP Authentication"

# Check gcloud authentication
if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
    check_pass "gcloud authenticated as: $ACTIVE_ACCOUNT"
else
    check_fail "gcloud is not authenticated"
fi

# Check project access
if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    check_pass "Access to project: $PROJECT_ID"
else
    check_fail "Cannot access project: $PROJECT_ID"
fi

# ============================================================================
# GKE Cluster Verification
# ============================================================================
print_section "GKE Cluster"

if [ -n "$GKE_CLUSTER" ]; then
    # Check cluster exists
    if gcloud container clusters describe "$GKE_CLUSTER" --zone="$GKE_ZONE" --project="$PROJECT_ID" &>/dev/null; then
        check_pass "GKE cluster exists: $GKE_CLUSTER"
        
        # Get cluster status
        CLUSTER_STATUS=$(gcloud container clusters describe "$GKE_CLUSTER" \
            --zone="$GKE_ZONE" \
            --project="$PROJECT_ID" \
            --format="value(status)" 2>/dev/null)
        
        if [ "$CLUSTER_STATUS" = "RUNNING" ]; then
            check_pass "GKE cluster status: RUNNING"
        else
            check_warn "GKE cluster status: $CLUSTER_STATUS"
        fi
        
        # Check node pool
        NODE_COUNT=$(gcloud container clusters describe "$GKE_CLUSTER" \
            --zone="$GKE_ZONE" \
            --project="$PROJECT_ID" \
            --format="value(currentNodeCount)" 2>/dev/null || echo "0")
        
        if [ "$NODE_COUNT" -gt 0 ]; then
            check_pass "GKE nodes running: $NODE_COUNT"
        else
            check_warn "No GKE nodes running"
        fi
    else
        check_fail "GKE cluster not found: $GKE_CLUSTER"
    fi
    
    # Check kubectl connectivity
    check_info "Testing kubectl connectivity..."
    
    # Get credentials
    gcloud container clusters get-credentials "$GKE_CLUSTER" \
        --zone="$GKE_ZONE" \
        --project="$PROJECT_ID" &>/dev/null || true
    
    if kubectl cluster-info &>/dev/null; then
        check_pass "kubectl can connect to cluster"
        
        # Check nodes
        READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
        if [ "$READY_NODES" -gt 0 ]; then
            check_pass "Kubernetes nodes ready: $READY_NODES"
        else
            check_warn "No Kubernetes nodes in Ready state"
        fi
        
        # Check system pods
        RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        if [ "$RUNNING_PODS" -gt 0 ]; then
            check_pass "System pods running: $RUNNING_PODS"
        else
            check_warn "No system pods running"
        fi
    else
        check_fail "kubectl cannot connect to cluster"
    fi
else
    check_warn "GKE cluster name not available"
fi

# ============================================================================
# Jenkins VM Verification
# ============================================================================
print_section "Jenkins VM"

if [ -n "$JENKINS_VM" ]; then
    # Check VM exists
    if gcloud compute instances describe "$JENKINS_VM" --zone="$ZONE" --project="$PROJECT_ID" &>/dev/null; then
        check_pass "Jenkins VM exists: $JENKINS_VM"
        
        # Get VM status
        VM_STATUS=$(gcloud compute instances describe "$JENKINS_VM" \
            --zone="$ZONE" \
            --project="$PROJECT_ID" \
            --format="value(status)" 2>/dev/null)
        
        if [ "$VM_STATUS" = "RUNNING" ]; then
            check_pass "Jenkins VM status: RUNNING"
        else
            check_warn "Jenkins VM status: $VM_STATUS"
        fi
        
        # Get external IP
        if [ -z "$JENKINS_IP" ]; then
            JENKINS_IP=$(gcloud compute instances describe "$JENKINS_VM" \
                --zone="$ZONE" \
                --project="$PROJECT_ID" \
                --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
        fi
        
        if [ -n "$JENKINS_IP" ]; then
            check_pass "Jenkins external IP: $JENKINS_IP"
        else
            check_warn "Jenkins has no external IP"
        fi
    else
        check_fail "Jenkins VM not found: $JENKINS_VM"
    fi
    
    # Check Jenkins HTTP accessibility
    if [ -n "$JENKINS_IP" ]; then
        check_info "Testing Jenkins HTTP connectivity..."
        
        JENKINS_PORT="${JENKINS_HTTP_PORT:-8080}"
        JENKINS_URL="http://$JENKINS_IP:$JENKINS_PORT"
        
        # Try to connect to Jenkins
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$JENKINS_URL/login" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "403" ]; then
            check_pass "Jenkins is accessible at: $JENKINS_URL (HTTP $HTTP_CODE)"
        elif [ "$HTTP_CODE" = "503" ]; then
            check_warn "Jenkins is starting up (HTTP 503). Try again in a few minutes."
        elif [ "$HTTP_CODE" = "000" ]; then
            check_warn "Jenkins is not responding. It may still be initializing."
        else
            check_warn "Jenkins returned HTTP $HTTP_CODE"
        fi
    fi
else
    check_warn "Jenkins VM name not available"
fi

# ============================================================================
# Service Account Verification
# ============================================================================
print_section "Service Accounts"

SA_NAME="${SERVICE_ACCOUNT_NAME:-gke-jenkins-sa}"

for suffix in "gke" "jenkins"; do
    SA_EMAIL="${SA_NAME}-${suffix}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
        check_pass "Service account exists: $SA_EMAIL"
        
        # Check for keys
        KEY_COUNT=$(gcloud iam service-accounts keys list \
            --iam-account="$SA_EMAIL" \
            --project="$PROJECT_ID" \
            --format="value(name)" \
            --filter="keyType=USER_MANAGED" 2>/dev/null | wc -l)
        
        if [ "$KEY_COUNT" -gt 0 ]; then
            check_pass "Service account has $KEY_COUNT user-managed key(s)"
        else
            check_info "Service account has no user-managed keys"
        fi
    else
        check_fail "Service account not found: $SA_EMAIL"
    fi
done

# Check local key file
KEY_PATH="${LOCAL_SA_KEY_PATH:-./keys/service-account-key.json}"
if [ -f "$KEY_PATH" ]; then
    check_pass "Local service account key exists: $KEY_PATH"
    
    # Validate key file
    if command -v jq &>/dev/null; then
        if jq -e '.type == "service_account"' "$KEY_PATH" &>/dev/null; then
            check_pass "Service account key is valid JSON"
        else
            check_warn "Service account key may be invalid"
        fi
    fi
else
    check_info "Local service account key not found at: $KEY_PATH"
fi

# ============================================================================
# Network Verification
# ============================================================================
print_section "Networking"

VPC_NAME="${VPC_NETWORK_NAME:-gke-jenkins-vpc}"
SUBNET_NAME="${SUBNET_NAME:-gke-jenkins-subnet}"
REGION="${GCP_REGION:-us-central1}"

# Check VPC
if gcloud compute networks describe "$VPC_NAME" --project="$PROJECT_ID" &>/dev/null; then
    check_pass "VPC network exists: $VPC_NAME"
else
    check_fail "VPC network not found: $VPC_NAME"
fi

# Check subnet
if gcloud compute networks subnets describe "$SUBNET_NAME" --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
    check_pass "Subnet exists: $SUBNET_NAME"
else
    check_fail "Subnet not found: $SUBNET_NAME"
fi

# Check firewall rules
FIREWALL_COUNT=$(gcloud compute firewall-rules list \
    --filter="network:$VPC_NAME" \
    --project="$PROJECT_ID" \
    --format="value(name)" 2>/dev/null | wc -l)

if [ "$FIREWALL_COUNT" -gt 0 ]; then
    check_pass "Firewall rules configured: $FIREWALL_COUNT rules"
else
    check_warn "No firewall rules found for VPC"
fi

# ============================================================================
# Summary
# ============================================================================
print_section "Verification Summary"

echo ""
TOTAL=$((PASSED + FAILED + WARNINGS))
echo "Total checks: $TOTAL"
echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ALL CRITICAL CHECKS PASSED                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    
    if [ -n "$JENKINS_URL" ]; then
        echo ""
        echo "Jenkins URL: $JENKINS_URL"
        echo ""
        echo "To get Jenkins initial admin password:"
        echo "  gcloud compute ssh $JENKINS_VM --zone=$ZONE --command='sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
    fi
    
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              SOME CHECKS FAILED                                ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Please review the failed checks above and take corrective action."
    exit 1
fi
