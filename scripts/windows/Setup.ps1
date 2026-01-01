#Requires -Version 5.1
<#
.SYNOPSIS
    Master Setup Script for Windows
    Executes all steps sequentially: prerequisites validation, Terraform initialization,
    service account key generation, infrastructure provisioning, and Jenkins VM configuration

.DESCRIPTION
    This script automates the complete infrastructure deployment process for Windows users.

.PARAMETER SkipPrerequisites
    Skip prerequisites validation

.PARAMETER SkipSaKey
    Skip service account key generation

.PARAMETER AutoApprove
    Auto-approve Terraform apply (non-interactive)

.PARAMETER PlanOnly
    Only run Terraform plan (no apply)

.EXAMPLE
    .\Setup.ps1
    .\Setup.ps1 -AutoApprove
    .\Setup.ps1 -PlanOnly
#>

[CmdletBinding()]
param(
    [switch]$SkipPrerequisites,
    [switch]$SkipSaKey,
    [switch]$AutoApprove,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

function Write-Banner {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "     GCP GKE Jenkins Infrastructure - Master Setup (Windows)   " -ForegroundColor Cyan
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Number, [string]$Message)
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "  STEP $Number`: $Message" -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

# Change to project directory
Set-Location $ProjectDir

Write-Banner

# Load environment variables if .env.ps1 exists
if (Test-Path ".\env.ps1") {
    Write-Info "Loading environment variables from .env.ps1"
    . .\env.ps1
} elseif (Test-Path ".\.env.ps1") {
    Write-Info "Loading environment variables from .env.ps1"
    . .\.env.ps1
} else {
    Write-Warning ".env.ps1 file not found. Using default values or existing environment variables."
    Write-Info "Copy .env.example.ps1 to .env.ps1 and configure before running."
}

# Set defaults
if (-not $env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID = "mobile-app-1-482109" }
if (-not $env:GCP_REGION) { $env:GCP_REGION = "us-central1" }
if (-not $env:GCP_ZONE) { $env:GCP_ZONE = "us-central1-a" }
if (-not $env:GKE_CLUSTER_NAME) { $env:GKE_CLUSTER_NAME = "autopilot-cluster-1" }
if (-not $env:JENKINS_VM_NAME) { $env:JENKINS_VM_NAME = "jenkins-server" }

# Display configuration
Write-Info "Configuration:"
Write-Host "  Project ID:     $env:GCP_PROJECT_ID"
Write-Host "  Region:         $env:GCP_REGION"
Write-Host "  Zone:           $env:GCP_ZONE"
Write-Host "  Cluster Name:   $env:GKE_CLUSTER_NAME"
Write-Host "  Jenkins VM:     $env:JENKINS_VM_NAME"
Write-Host ""

# ============================================================================
# STEP 1: Prerequisites Validation
# ============================================================================
if (-not $SkipPrerequisites) {
    Write-Step 1 "Prerequisites Validation"
    
    $prereqScript = Join-Path $ScriptDir "Validate-Prerequisites.ps1"
    if (Test-Path $prereqScript) {
        & $prereqScript
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Prerequisites validation failed. Please fix the issues and try again."
            exit 1
        }
    } else {
        Write-Warning "Prerequisites validation script not found. Skipping..."
    }
} else {
    Write-Step 1 "Prerequisites Validation (SKIPPED)"
}

# ============================================================================
# STEP 2: Enable Required GCP APIs
# ============================================================================
Write-Step 2 "Enable Required GCP APIs"

Write-Info "Enabling required APIs for project: $env:GCP_PROJECT_ID"

$requiredApis = @(
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "servicenetworking.googleapis.com"
)

foreach ($api in $requiredApis) {
    Write-Info "Enabling API: $api"
    gcloud services enable $api --project=$env:GCP_PROJECT_ID --quiet 2>$null
}

Write-Success "API enablement complete"

# ============================================================================
# STEP 3: Service Account Key Generation (Optional)
# ============================================================================
if (-not $SkipSaKey) {
    Write-Step 3 "Service Account Key Generation"
    
    $keyPath = if ($env:LOCAL_SA_KEY_PATH) { $env:LOCAL_SA_KEY_PATH } else { ".\keys\service-account-key.json" }
    
    if (Test-Path $keyPath) {
        Write-Warning "Service account key already exists at: $keyPath"
        $response = Read-Host "Do you want to generate a new key? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            $saScript = Join-Path $ScriptDir "Generate-ServiceAccountKey.ps1"
            if (Test-Path $saScript) {
                & $saScript
            }
        } else {
            Write-Info "Using existing key"
        }
    } else {
        $saScript = Join-Path $ScriptDir "Generate-ServiceAccountKey.ps1"
        if (Test-Path $saScript) {
            & $saScript
        } else {
            Write-Warning "Service account key generation script not found. Terraform will create the key."
        }
    }
} else {
    Write-Step 3 "Service Account Key Generation (SKIPPED)"
}

# ============================================================================
# STEP 4: Terraform Initialization
# ============================================================================
Write-Step 4 "Terraform Initialization"

Write-Info "Initializing Terraform..."
terraform init -upgrade

if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform initialization failed"
    exit 1
}

Write-Success "Terraform initialized"

# ============================================================================
# STEP 5: Create terraform.tfvars
# ============================================================================
Write-Step 5 "Configure Terraform Variables"

if (-not (Test-Path "terraform.tfvars")) {
    Write-Info "Creating terraform.tfvars from environment variables..."
    
    $tfvarsContent = @"
# Auto-generated terraform.tfvars
# Generated on: $(Get-Date)

project_id = "$env:GCP_PROJECT_ID"
region     = "$env:GCP_REGION"
zone       = "$env:GCP_ZONE"

# GKE Configuration
gke_cluster_name      = "$env:GKE_CLUSTER_NAME"
gke_node_count        = $(if ($env:GKE_NODE_COUNT) { $env:GKE_NODE_COUNT } else { "2" })
gke_min_node_count    = $(if ($env:GKE_MIN_NODE_COUNT) { $env:GKE_MIN_NODE_COUNT } else { "1" })
gke_max_node_count    = $(if ($env:GKE_MAX_NODE_COUNT) { $env:GKE_MAX_NODE_COUNT } else { "5" })
gke_node_machine_type = "$(if ($env:GKE_NODE_MACHINE_TYPE) { $env:GKE_NODE_MACHINE_TYPE } else { "e2-medium" })"
gke_node_disk_size_gb = $(if ($env:GKE_NODE_DISK_SIZE_GB) { $env:GKE_NODE_DISK_SIZE_GB } else { "50" })
gke_preemptible_nodes = $(if ($env:GKE_PREEMPTIBLE_NODES) { $env:GKE_PREEMPTIBLE_NODES } else { "true" })

# Jenkins Configuration
jenkins_vm_name      = "$env:JENKINS_VM_NAME"
jenkins_machine_type = "$(if ($env:JENKINS_MACHINE_TYPE) { $env:JENKINS_MACHINE_TYPE } else { "e2-medium" })"
jenkins_disk_size_gb = $(if ($env:JENKINS_DISK_SIZE_GB) { $env:JENKINS_DISK_SIZE_GB } else { "50" })
jenkins_preemptible  = $(if ($env:JENKINS_PREEMPTIBLE) { $env:JENKINS_PREEMPTIBLE } else { "false" })
jenkins_http_port    = $(if ($env:JENKINS_HTTP_PORT) { $env:JENKINS_HTTP_PORT } else { "8080" })

# Service Account
service_account_name     = "$(if ($env:SERVICE_ACCOUNT_NAME) { $env:SERVICE_ACCOUNT_NAME } else { "gke-jenkins-sa" })"
service_account_key_path = "$(if ($env:SERVICE_ACCOUNT_KEY_PATH) { $env:SERVICE_ACCOUNT_KEY_PATH } else { "/var/lib/jenkins/keys/mobile-app-1-482109-e631e1327727.json" })"

# Python
python_version = "$(if ($env:PYTHON_VERSION) { $env:PYTHON_VERSION } else { "3.11" })"

# Labels
environment = "$(if ($env:ENVIRONMENT) { $env:ENVIRONMENT } else { "development" })"
team        = "$(if ($env:TEAM) { $env:TEAM } else { "devops" })"
application = "$(if ($env:APPLICATION) { $env:APPLICATION } else { "jenkins-cicd" })"
"@

    $tfvarsContent | Out-File -FilePath "terraform.tfvars" -Encoding UTF8
    Write-Success "terraform.tfvars created"
} else {
    Write-Info "terraform.tfvars already exists"
}

# ============================================================================
# STEP 6: Terraform Plan
# ============================================================================
Write-Step 6 "Terraform Plan"

Write-Info "Running Terraform plan..."
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform plan failed"
    exit 1
}

Write-Success "Terraform plan complete"

if ($PlanOnly) {
    Write-Info "Plan-only mode. Exiting without applying."
    Write-Success "Setup complete (plan only)"
    exit 0
}

# ============================================================================
# STEP 7: Terraform Apply
# ============================================================================
Write-Step 7 "Terraform Apply"

if ($AutoApprove) {
    Write-Info "Auto-approve enabled. Applying Terraform plan..."
    terraform apply tfplan
} else {
    Write-Info "Review the plan above and confirm to proceed."
    $response = Read-Host "Do you want to apply this plan? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        terraform apply tfplan
    } else {
        Write-Warning "Terraform apply cancelled"
        exit 0
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform apply failed"
    exit 1
}

Write-Success "Terraform apply complete"

# ============================================================================
# STEP 8: Post-Deployment Configuration
# ============================================================================
Write-Step 8 "Post-Deployment Configuration"

# Get outputs
Write-Info "Retrieving deployment outputs..."

$gkeCluster = terraform output -raw gke_cluster_name 2>$null
$gkeZone = terraform output -raw gke_cluster_location 2>$null
$jenkinsIp = terraform output -raw jenkins_external_ip 2>$null
$jenkinsUrl = terraform output -raw jenkins_url 2>$null

# Configure kubectl
if ($gkeCluster -and $gkeZone) {
    Write-Info "Configuring kubectl for GKE cluster..."
    gcloud container clusters get-credentials $gkeCluster `
        --zone $gkeZone `
        --project $env:GCP_PROJECT_ID 2>$null
}

# ============================================================================
# STEP 9: Verification
# ============================================================================
Write-Step 9 "Verification"

Write-Info "Running verification checks..."

# Verify GKE cluster
if ($gkeCluster) {
    Write-Info "Checking GKE cluster status..."
    $clusterInfo = kubectl cluster-info 2>$null
    if ($clusterInfo) {
        Write-Success "GKE cluster is accessible"
        kubectl get nodes
    } else {
        Write-Warning "Could not connect to GKE cluster"
    }
}

# Verify Jenkins VM
if ($jenkinsIp) {
    Write-Info "Checking Jenkins VM accessibility..."
    try {
        $response = Invoke-WebRequest -Uri "http://${jenkinsIp}:8080" -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue
        Write-Success "Jenkins is accessible at: $jenkinsUrl"
    } catch {
        Write-Warning "Jenkins may still be starting up. Check again in a few minutes."
    }
}

# ============================================================================
# Summary
# ============================================================================
Write-Step 10 "Deployment Summary"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                    DEPLOYMENT COMPLETE                         " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

terraform output connection_info 2>$null

Write-Host ""
Write-Host "Next Steps:"
Write-Host "  1. Wait 5-10 minutes for Jenkins to fully initialize"
Write-Host "  2. Access Jenkins at: $jenkinsUrl"
Write-Host "  3. Get initial admin password:"
Write-Host "     gcloud compute ssh $env:JENKINS_VM_NAME --zone=$gkeZone --command='sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
Write-Host "  4. Configure Jenkins plugins and pipelines"
Write-Host ""

Write-Success "Master setup complete!"
