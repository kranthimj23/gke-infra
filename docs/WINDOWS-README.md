# GCP GKE Jenkins Infrastructure - Windows Setup Guide

Complete step-by-step guide for setting up the GCP GKE Jenkins infrastructure on Windows.

## Table of Contents

1. [Prerequisites Installation](#1-prerequisites-installation)
2. [GCP Authentication](#2-gcp-authentication)
3. [Project Configuration](#3-project-configuration)
4. [Infrastructure Deployment](#4-infrastructure-deployment)
5. [Verification](#5-verification)
6. [Accessing Jenkins](#6-accessing-jenkins)
7. [Cleanup](#7-cleanup)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerequisites Installation

### 1.1 Install Chocolatey (Package Manager)

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Close and reopen PowerShell as Administrator.

### 1.2 Install Required Tools

```powershell
# Install Terraform
choco install terraform -y

# Install Google Cloud SDK
choco install gcloudsdk -y

# Install kubectl
choco install kubernetes-cli -y

# Install Git
choco install git -y

# Install Python 3.11
choco install python311 -y

# Optional: Install jq for JSON processing
choco install jq -y
```

### 1.3 Verify Installations

Open a new PowerShell window and verify:

```powershell
terraform version
gcloud version
kubectl version --client
git --version
python --version
```

### 1.4 Alternative: Manual Installation

If you prefer manual installation:

| Tool | Download URL |
|------|--------------|
| Terraform | https://developer.hashicorp.com/terraform/downloads |
| Google Cloud SDK | https://cloud.google.com/sdk/docs/install |
| kubectl | https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/ |
| Git | https://git-scm.com/download/win |
| Python 3.11 | https://www.python.org/downloads/ |

---

## 2. GCP Authentication

### 2.1 Initialize Google Cloud SDK

Open PowerShell and run:

```powershell
# Initialize gcloud (opens browser for authentication)
gcloud init
```

Follow the prompts:
1. Choose to log in with a new account
2. A browser window will open - log in with your Google account
3. Select the project: `mobile-app-1-482109`
4. Choose a default region: `us-central1`

### 2.2 Set Application Default Credentials

```powershell
# Set up application default credentials for Terraform
gcloud auth application-default login
```

### 2.3 Verify Authentication

```powershell
# Check active account
gcloud auth list

# Check current project
gcloud config get-value project

# Test project access
gcloud projects describe mobile-app-1-482109
```

---

## 3. Project Configuration

### 3.1 Clone or Navigate to Project

```powershell
# Navigate to project directory
cd C:\path\to\gcp-gke-jenkins-terraform

# Or clone from repository (if applicable)
# git clone <repository-url>
# cd gcp-gke-jenkins-terraform
```

### 3.2 Configure Environment Variables

```powershell
# Copy the environment template
Copy-Item .env.example.ps1 .env.ps1

# Edit the configuration file
notepad .env.ps1
```

Edit `.env.ps1` with your settings:

```powershell
# Key settings to verify/modify:
$env:GCP_PROJECT_ID = "mobile-app-1-482109"
$env:GCP_REGION = "us-central1"
$env:GCP_ZONE = "us-central1-a"
$env:GKE_CLUSTER_NAME = "autopilot-cluster-1"
$env:JENKINS_VM_NAME = "jenkins-server"
```

### 3.3 Load Environment Variables

```powershell
# Load the environment variables
. .\.env.ps1
```

### 3.4 Validate Prerequisites

```powershell
# Run the prerequisites validation script
.\scripts\windows\Validate-Prerequisites.ps1
```

---

## 4. Infrastructure Deployment

### 4.1 Option A: Automated Setup (Recommended)

Run the master setup script:

```powershell
# Interactive mode (recommended for first run)
.\scripts\windows\Setup.ps1

# Or with auto-approve (non-interactive)
.\scripts\windows\Setup.ps1 -AutoApprove

# Or plan only (no changes made)
.\scripts\windows\Setup.ps1 -PlanOnly
```

### 4.2 Option B: Manual Step-by-Step

If you prefer manual control:

#### Step 1: Enable GCP APIs

```powershell
$apis = @(
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "Enabling $api..."
    gcloud services enable $api --project=$env:GCP_PROJECT_ID
}
```

#### Step 2: Generate Service Account Key

```powershell
.\scripts\windows\Generate-ServiceAccountKey.ps1
```

#### Step 3: Initialize Terraform

```powershell
terraform init -upgrade
```

#### Step 4: Create Terraform Variables File

```powershell
# Copy the example file
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit with your values
notepad terraform.tfvars
```

#### Step 5: Review Terraform Plan

```powershell
terraform plan -out=tfplan
```

Review the output carefully to understand what resources will be created.

#### Step 6: Apply Terraform Configuration

```powershell
# Apply the plan
terraform apply tfplan

# Or apply directly with auto-approve
terraform apply -auto-approve
```

#### Step 7: Configure kubectl

```powershell
# Get GKE cluster credentials
gcloud container clusters get-credentials $env:GKE_CLUSTER_NAME `
    --zone $env:GCP_ZONE `
    --project $env:GCP_PROJECT_ID
```

---

## 5. Verification

### 5.1 Run Verification Script

```powershell
.\scripts\windows\Verify.ps1
```

### 5.2 Manual Verification

#### Check GKE Cluster

```powershell
# Verify cluster is running
gcloud container clusters describe $env:GKE_CLUSTER_NAME `
    --zone $env:GCP_ZONE `
    --format="value(status)"

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

#### Check Jenkins VM

```powershell
# Get Jenkins VM status
gcloud compute instances describe jenkins-server `
    --zone $env:GCP_ZONE `
    --format="value(status)"

# Get Jenkins external IP
$jenkinsIp = gcloud compute instances describe jenkins-server `
    --zone $env:GCP_ZONE `
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

Write-Host "Jenkins IP: $jenkinsIp"
```

#### Check Terraform Outputs

```powershell
# View all outputs
terraform output

# Get specific outputs
terraform output jenkins_url
terraform output gke_cluster_name
```

---

## 6. Accessing Jenkins

### 6.1 Get Jenkins URL

```powershell
$jenkinsUrl = terraform output -raw jenkins_url
Write-Host "Jenkins URL: $jenkinsUrl"
```

### 6.2 Get Initial Admin Password

```powershell
# SSH to Jenkins VM and get password
gcloud compute ssh jenkins-server --zone=$env:GCP_ZONE `
    --command="sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
```

### 6.3 Complete Jenkins Setup

1. Open the Jenkins URL in your browser
2. Enter the initial admin password
3. Install suggested plugins
4. Create your admin user
5. Configure Jenkins URL

### 6.4 Configure Jenkins for GKE

The Jenkins VM is pre-configured with:
- Google Cloud SDK (gcloud)
- kubectl (configured for your GKE cluster)
- Docker
- Python 3.11

Environment variables available:
- `GOOGLE_APPLICATION_CREDENTIALS` - Path to service account key
- `GCP_PROJECT_ID` - Your GCP project ID
- `GKE_CLUSTER_NAME` - Your GKE cluster name
- `GKE_CLUSTER_ZONE` - Your GKE cluster zone

---

## 7. Cleanup

### 7.1 Destroy All Resources

```powershell
# Interactive mode
.\scripts\windows\Destroy.ps1

# Auto-approve mode (DANGEROUS)
.\scripts\windows\Destroy.ps1 -AutoApprove

# Full cleanup including local files and service account keys
.\scripts\windows\Destroy.ps1 -AutoApprove -CleanupLocal -CleanupSaKeys
```

### 7.2 Manual Cleanup

```powershell
# Destroy Terraform resources
terraform destroy

# Remove local files (optional)
Remove-Item terraform.tfstate, terraform.tfstate.backup, tfplan -Force -ErrorAction SilentlyContinue
Remove-Item .terraform -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item terraform.tfvars -Force -ErrorAction SilentlyContinue
Remove-Item keys -Recurse -Force -ErrorAction SilentlyContinue
```

---

## 8. Troubleshooting

### 8.1 PowerShell Execution Policy

If you get execution policy errors:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or for current session only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### 8.2 gcloud Authentication Issues

```powershell
# Re-authenticate
gcloud auth login
gcloud auth application-default login

# Clear credentials and start fresh
gcloud auth revoke --all
gcloud auth login
```

### 8.3 Terraform State Issues

```powershell
# Refresh state
terraform refresh

# If state is corrupted, import resources
terraform import <resource_type>.<name> <resource_id>
```

### 8.4 kubectl Connection Issues

```powershell
# Re-fetch credentials
gcloud container clusters get-credentials $env:GKE_CLUSTER_NAME `
    --zone $env:GCP_ZONE `
    --project $env:GCP_PROJECT_ID

# Check current context
kubectl config current-context

# List all contexts
kubectl config get-contexts
```

### 8.5 Jenkins Not Accessible

```powershell
# Check VM status
gcloud compute instances describe jenkins-server --zone=$env:GCP_ZONE

# Check startup script logs
gcloud compute ssh jenkins-server --zone=$env:GCP_ZONE `
    --command="sudo cat /var/log/jenkins-setup.log"

# Check Jenkins service status
gcloud compute ssh jenkins-server --zone=$env:GCP_ZONE `
    --command="sudo systemctl status jenkins"

# Restart Jenkins if needed
gcloud compute ssh jenkins-server --zone=$env:GCP_ZONE `
    --command="sudo systemctl restart jenkins"
```

### 8.6 API Not Enabled Errors

```powershell
# Enable specific API
gcloud services enable <api-name> --project=$env:GCP_PROJECT_ID

# List enabled APIs
gcloud services list --enabled --project=$env:GCP_PROJECT_ID
```

### 8.7 Quota Exceeded Errors

Check your GCP quotas:
1. Go to https://console.cloud.google.com/iam-admin/quotas
2. Filter by the resource type (e.g., "CPUs", "IP addresses")
3. Request quota increase if needed

---

## Quick Reference Commands

```powershell
# Load environment
. .\.env.ps1

# Validate prerequisites
.\scripts\windows\Validate-Prerequisites.ps1

# Deploy infrastructure
.\scripts\windows\Setup.ps1

# Verify deployment
.\scripts\windows\Verify.ps1

# Get Jenkins URL
terraform output jenkins_url

# Get Jenkins password
gcloud compute ssh jenkins-server --zone=$env:GCP_ZONE `
    --command="sudo cat /var/lib/jenkins/secrets/initialAdminPassword"

# Connect to GKE
gcloud container clusters get-credentials $env:GKE_CLUSTER_NAME `
    --zone $env:GCP_ZONE --project $env:GCP_PROJECT_ID

# Destroy everything
.\scripts\windows\Destroy.ps1
```

---

## Cost Estimates

| Resource | Configuration | Est. Monthly Cost |
|----------|---------------|-------------------|
| GKE Nodes (2x e2-medium, preemptible) | 2 vCPU, 4GB RAM each | ~$29.20 |
| GKE Boot Disks (2x 50GB) | pd-standard | ~$4.00 |
| Jenkins VM (e2-medium) | 2 vCPU, 4GB RAM | ~$24.27 |
| Jenkins Boot Disk (50GB) | pd-standard | ~$2.00 |
| Cloud NAT | Per-VM hour + data | ~$3.00 |
| External IP | Static IP | ~$2.92 |
| Egress Traffic | ~10GB | ~$1.20 |
| **Total** | | **~$66.59/month** |

---

## Support

For issues:
1. Check the [Troubleshooting](#8-troubleshooting) section
2. Review GCP documentation
3. Check Terraform logs: `$env:TF_LOG = "DEBUG"; terraform apply`
