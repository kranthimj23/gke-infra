# Prerequisites for GCP GKE Jenkins Infrastructure

This document outlines all prerequisites required to provision the GKE cluster and Jenkins VM infrastructure.

## Required Tools

### 1. Terraform (>= 1.5.0)

**Linux (Ubuntu/Debian):**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**macOS:**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Windows (PowerShell as Administrator):**
```powershell
choco install terraform
# OR using winget
winget install Hashicorp.Terraform
```

### 2. Google Cloud SDK (gcloud CLI >= 450.0.0)

**Linux:**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
```

**macOS:**
```bash
brew install --cask google-cloud-sdk
gcloud init
```

**Windows:**
Download and run the installer from: https://cloud.google.com/sdk/docs/install

### 3. kubectl (>= 1.28.0)

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**macOS:**
```bash
brew install kubectl
```

**Windows:**
```powershell
choco install kubernetes-cli
```

### 4. Git (>= 2.40.0)

**Linux:**
```bash
sudo apt update && sudo apt install git
```

**macOS:**
```bash
brew install git
```

**Windows:**
```powershell
choco install git
```

### 5. Python 3.11

**Linux:**
```bash
sudo apt update && sudo apt install python3.11 python3.11-venv python3-pip
```

**macOS:**
```bash
brew install python@3.11
```

**Windows:**
```powershell
choco install python311
```

## GCP Prerequisites

### Required APIs
The following GCP APIs must be enabled in your project:

- Compute Engine API (`compute.googleapis.com`)
- Kubernetes Engine API (`container.googleapis.com`)
- Cloud Resource Manager API (`cloudresourcemanager.googleapis.com`)
- IAM API (`iam.googleapis.com`)
- Service Account Credentials API (`iamcredentials.googleapis.com`)

### Required IAM Permissions
The user or service account running Terraform needs the following roles:

- `roles/compute.admin` - For creating VMs and networking resources
- `roles/container.admin` - For creating GKE clusters
- `roles/iam.serviceAccountAdmin` - For creating service accounts
- `roles/iam.serviceAccountKeyAdmin` - For creating service account keys
- `roles/resourcemanager.projectIamAdmin` - For assigning IAM roles

## Authentication

### Option 1: User Account (Development)
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project mobile-app-1-482109
```

### Option 2: Service Account (CI/CD)
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
```

## Verification

Run the validation script to verify all prerequisites:
```bash
./scripts/validate-prerequisites.sh
```

## Network Requirements

Ensure the following outbound connectivity:
- `*.googleapis.com` (port 443) - GCP API access
- `*.gcr.io` (port 443) - Container registry
- `github.com` (port 443) - Repository access

## Quotas

Verify your GCP project has sufficient quotas:
- CPUs: At least 8 vCPUs in us-central1
- IP Addresses: At least 5 external IPs
- Persistent Disk SSD: At least 200 GB
