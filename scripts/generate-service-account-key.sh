#!/bin/bash
#
# Service Account Key Generation Script
# Creates a GCP service account and generates a JSON key file
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values (can be overridden by environment variables)
PROJECT_ID="${GCP_PROJECT_ID:-speedy-insight-483010-m3}"
SA_NAME="${SERVICE_ACCOUNT_NAME:-gke-jenkins-sa}"
SA_DISPLAY_NAME="${SA_DISPLAY_NAME:-GKE Jenkins Service Account}"
KEY_OUTPUT_PATH="${LOCAL_SA_KEY_PATH:-./keys/service-account-key.json}"
JENKINS_KEY_PATH="${SERVICE_ACCOUNT_KEY_PATH:-/var/lib/jenkins/keys/speedy-insight-483010-m3-e631e1327727.json}"

# IAM roles for the service account
IAM_ROLES=(
    "roles/container.developer"
    "roles/container.clusterViewer"
    "roles/storage.admin"
    "roles/artifactregistry.writer"
    "roles/logging.logWriter"
    "roles/monitoring.metricWriter"
    "roles/compute.instanceAdmin.v1"
    "roles/iam.serviceAccountUser"
)

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --project      GCP Project ID (default: $PROJECT_ID)"
    echo "  -n, --name         Service account name (default: $SA_NAME)"
    echo "  -o, --output       Output path for key file (default: $KEY_OUTPUT_PATH)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GCP_PROJECT_ID           GCP Project ID"
    echo "  SERVICE_ACCOUNT_NAME     Service account name"
    echo "  LOCAL_SA_KEY_PATH        Local path for key file"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT_ID="$2"
            shift 2
            ;;
        -n|--name)
            SA_NAME="$2"
            shift 2
            ;;
        -o|--output)
            KEY_OUTPUT_PATH="$2"
            shift 2
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

print_header "Service Account Key Generation"

# Validate gcloud is installed and authenticated
print_info "Validating gcloud CLI..."
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
    print_error "gcloud is not authenticated. Please run: gcloud auth login"
    exit 1
fi

# Set project
print_info "Setting project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# Create output directory
KEY_DIR=$(dirname "$KEY_OUTPUT_PATH")
if [ ! -d "$KEY_DIR" ]; then
    print_info "Creating directory: $KEY_DIR"
    mkdir -p "$KEY_DIR"
fi

# Full service account email
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

print_header "Creating Service Account"

# Check if service account exists
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &> /dev/null; then
    print_info "Service account already exists: $SA_EMAIL"
else
    print_info "Creating service account: $SA_NAME"
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="$SA_DISPLAY_NAME" \
        --description="Service account for GKE and Jenkins CI/CD operations" \
        --project="$PROJECT_ID"
    print_success "Service account created: $SA_EMAIL"
fi

print_header "Assigning IAM Roles"

for role in "${IAM_ROLES[@]}"; do
    print_info "Assigning role: $role"
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$role" \
        --condition=None \
        --quiet 2>/dev/null || true
done

print_success "All IAM roles assigned"

print_header "Generating Service Account Key"

# Check for existing keys and warn
EXISTING_KEYS=$(gcloud iam service-accounts keys list \
    --iam-account="$SA_EMAIL" \
    --project="$PROJECT_ID" \
    --format="value(name)" \
    --filter="keyType=USER_MANAGED" 2>/dev/null | wc -l)

if [ "$EXISTING_KEYS" -gt 0 ]; then
    print_info "Warning: Service account has $EXISTING_KEYS existing user-managed key(s)"
fi

# Generate new key
print_info "Generating new key file: $KEY_OUTPUT_PATH"
gcloud iam service-accounts keys create "$KEY_OUTPUT_PATH" \
    --iam-account="$SA_EMAIL" \
    --project="$PROJECT_ID"

# Set secure permissions
chmod 600 "$KEY_OUTPUT_PATH"

print_success "Service account key generated: $KEY_OUTPUT_PATH"

print_header "Verification"

# Verify the key file
if [ -f "$KEY_OUTPUT_PATH" ]; then
    KEY_SIZE=$(stat -f%z "$KEY_OUTPUT_PATH" 2>/dev/null || stat -c%s "$KEY_OUTPUT_PATH" 2>/dev/null)
    print_success "Key file exists (size: $KEY_SIZE bytes)"
    
    # Extract key ID from file
    if command -v jq &> /dev/null; then
        KEY_ID=$(jq -r '.private_key_id' "$KEY_OUTPUT_PATH" 2>/dev/null || echo "unknown")
        print_info "Key ID: $KEY_ID"
    fi
else
    print_error "Key file was not created"
    exit 1
fi

print_header "Summary"

echo ""
echo "Service Account Details:"
echo "  Email: $SA_EMAIL"
echo "  Key Path: $KEY_OUTPUT_PATH"
echo "  Jenkins Path: $JENKINS_KEY_PATH"
echo ""
echo "To use this key:"
echo "  export GOOGLE_APPLICATION_CREDENTIALS=\"$KEY_OUTPUT_PATH\""
echo ""
echo "To activate the service account:"
echo "  gcloud auth activate-service-account --key-file=\"$KEY_OUTPUT_PATH\""
echo ""
echo "To copy to Jenkins VM (after VM is created):"
echo "  gcloud compute scp \"$KEY_OUTPUT_PATH\" jenkins-server:$JENKINS_KEY_PATH --zone=us-central1-a"
echo ""

print_success "Service account key generation complete!"
