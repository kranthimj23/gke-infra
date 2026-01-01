#!/bin/bash
#
# Prerequisites Validation Script
# Validates all required tools and configurations for GCP GKE Jenkins infrastructure
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Minimum versions
MIN_TERRAFORM_VERSION="1.5.0"
MIN_GCLOUD_VERSION="450.0.0"
MIN_KUBECTL_VERSION="1.28.0"
MIN_GIT_VERSION="2.40.0"
MIN_PYTHON_VERSION="3.11"

# Counters
ERRORS=0
WARNINGS=0

print_header() {
    echo ""
    echo "=============================================="
    echo "$1"
    echo "=============================================="
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((ERRORS++))
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((WARNINGS++))
}

version_gte() {
    # Returns 0 if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

check_command() {
    local cmd=$1
    local name=$2
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

print_header "GCP GKE Jenkins Infrastructure - Prerequisites Validation"

# Check Terraform
print_header "Checking Terraform"
if check_command terraform "Terraform"; then
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version": "[^"]*"' | cut -d'"' -f4 || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if version_gte "$TERRAFORM_VERSION" "$MIN_TERRAFORM_VERSION"; then
        print_success "Terraform $TERRAFORM_VERSION installed (minimum: $MIN_TERRAFORM_VERSION)"
    else
        print_error "Terraform $TERRAFORM_VERSION is below minimum version $MIN_TERRAFORM_VERSION"
    fi
else
    print_error "Terraform is not installed"
fi

# Check gcloud CLI
print_header "Checking Google Cloud SDK"
if check_command gcloud "gcloud"; then
    GCLOUD_VERSION=$(gcloud version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    if version_gte "$GCLOUD_VERSION" "$MIN_GCLOUD_VERSION"; then
        print_success "gcloud CLI $GCLOUD_VERSION installed (minimum: $MIN_GCLOUD_VERSION)"
    else
        print_warning "gcloud CLI $GCLOUD_VERSION may be below recommended version $MIN_GCLOUD_VERSION"
    fi
    
    # Check gcloud authentication
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
        ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
        print_success "gcloud authenticated as: $ACTIVE_ACCOUNT"
    else
        print_warning "gcloud is not authenticated. Run: gcloud auth login"
    fi
    
    # Check current project
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    if [ -n "$CURRENT_PROJECT" ]; then
        print_success "gcloud project set to: $CURRENT_PROJECT"
    else
        print_warning "No gcloud project set. Run: gcloud config set project PROJECT_ID"
    fi
else
    print_error "gcloud CLI is not installed"
fi

# Check kubectl
print_header "Checking kubectl"
if check_command kubectl "kubectl"; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": "[^"]*"' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || kubectl version --client 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if version_gte "$KUBECTL_VERSION" "$MIN_KUBECTL_VERSION"; then
        print_success "kubectl $KUBECTL_VERSION installed (minimum: $MIN_KUBECTL_VERSION)"
    else
        print_warning "kubectl $KUBECTL_VERSION may be below recommended version $MIN_KUBECTL_VERSION"
    fi
else
    print_error "kubectl is not installed"
fi

# Check Git
print_header "Checking Git"
if check_command git "Git"; then
    GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if version_gte "$GIT_VERSION" "$MIN_GIT_VERSION"; then
        print_success "Git $GIT_VERSION installed (minimum: $MIN_GIT_VERSION)"
    else
        print_warning "Git $GIT_VERSION may be below recommended version $MIN_GIT_VERSION"
    fi
else
    print_error "Git is not installed"
fi

# Check Python
print_header "Checking Python"
PYTHON_CMD=""
if check_command python3.11 "Python 3.11"; then
    PYTHON_CMD="python3.11"
elif check_command python3 "Python 3"; then
    PYTHON_CMD="python3"
elif check_command python "Python"; then
    PYTHON_CMD="python"
fi

if [ -n "$PYTHON_CMD" ]; then
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
    if version_gte "$PYTHON_VERSION" "$MIN_PYTHON_VERSION"; then
        print_success "Python $PYTHON_VERSION installed (minimum: $MIN_PYTHON_VERSION)"
    else
        print_warning "Python $PYTHON_VERSION is below recommended version $MIN_PYTHON_VERSION"
    fi
else
    print_error "Python is not installed"
fi

# Check jq (optional but recommended)
print_header "Checking Optional Tools"
if check_command jq "jq"; then
    JQ_VERSION=$(jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")
    print_success "jq $JQ_VERSION installed (optional, recommended)"
else
    print_warning "jq is not installed (optional, but recommended for JSON processing)"
fi

# Check environment variables
print_header "Checking Environment Variables"
if [ -f ".env" ]; then
    print_success ".env file found"
    source .env 2>/dev/null || true
else
    print_warning ".env file not found. Copy .env.example to .env and configure"
fi

if [ -n "$GCP_PROJECT_ID" ]; then
    print_success "GCP_PROJECT_ID is set: $GCP_PROJECT_ID"
else
    print_warning "GCP_PROJECT_ID environment variable not set"
fi

if [ -n "$GCP_REGION" ]; then
    print_success "GCP_REGION is set: $GCP_REGION"
else
    print_warning "GCP_REGION environment variable not set"
fi

if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        print_success "GOOGLE_APPLICATION_CREDENTIALS file exists: $GOOGLE_APPLICATION_CREDENTIALS"
    else
        print_warning "GOOGLE_APPLICATION_CREDENTIALS set but file not found: $GOOGLE_APPLICATION_CREDENTIALS"
    fi
else
    print_warning "GOOGLE_APPLICATION_CREDENTIALS not set (required for service account auth)"
fi

# Check GCP APIs (if authenticated)
print_header "Checking GCP APIs"
if check_command gcloud "gcloud" && [ -n "$CURRENT_PROJECT" ]; then
    REQUIRED_APIS=(
        "compute.googleapis.com"
        "container.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "iam.googleapis.com"
        "iamcredentials.googleapis.com"
    )
    
    ENABLED_APIS=$(gcloud services list --enabled --format="value(config.name)" 2>/dev/null || echo "")
    
    for api in "${REQUIRED_APIS[@]}"; do
        if echo "$ENABLED_APIS" | grep -q "$api"; then
            print_success "API enabled: $api"
        else
            print_warning "API not enabled: $api (run: gcloud services enable $api)"
        fi
    done
else
    print_warning "Skipping API check - gcloud not authenticated or project not set"
fi

# Summary
print_header "Validation Summary"
echo ""
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All prerequisites validated successfully!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Validation completed with $WARNINGS warning(s).${NC}"
    echo "Review warnings above and address if needed."
    exit 0
else
    echo -e "${RED}Validation failed with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo "Please install missing prerequisites before proceeding."
    exit 1
fi
