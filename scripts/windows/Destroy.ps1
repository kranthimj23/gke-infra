#Requires -Version 5.1
<#
.SYNOPSIS
    Cleanup/Destroy Script for Windows
    Destroys all provisioned GCP resources

.DESCRIPTION
    This script destroys all GCP resources created by Terraform.
    WARNING: This action is irreversible!

.PARAMETER AutoApprove
    Auto-approve Terraform destroy (DANGEROUS)

.PARAMETER CleanupSaKeys
    Also delete service account keys from GCP

.PARAMETER CleanupLocal
    Also delete local files (keys, tfstate, etc.)

.EXAMPLE
    .\Destroy.ps1
    .\Destroy.ps1 -AutoApprove
    .\Destroy.ps1 -AutoApprove -CleanupLocal -CleanupSaKeys
#>

[CmdletBinding()]
param(
    [switch]$AutoApprove,
    [switch]$CleanupSaKeys,
    [switch]$CleanupLocal
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

function Write-Banner {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "                                                                " -ForegroundColor Red
    Write-Host "     GCP GKE Jenkins Infrastructure - DESTROY Script           " -ForegroundColor Red
    Write-Host "                                                                " -ForegroundColor Red
    Write-Host "     WARNING: This will destroy ALL provisioned resources!     " -ForegroundColor Red
    Write-Host "                                                                " -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
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

# Load environment variables
if (Test-Path ".\.env.ps1") {
    . .\.env.ps1
}

$ProjectId = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "speedy-insight-483010-m3" }
$Zone = if ($env:GCP_ZONE) { $env:GCP_ZONE } else { "us-central1-a" }

# ============================================================================
# Confirmation
# ============================================================================
if (-not $AutoApprove) {
    Write-Host "WARNING: This script will destroy the following resources:" -ForegroundColor Red
    Write-Host ""
    Write-Host "  - GKE Cluster and all node pools"
    Write-Host "  - Jenkins VM and associated disks"
    Write-Host "  - VPC Network, subnets, and firewall rules"
    Write-Host "  - Cloud NAT and Cloud Router"
    Write-Host "  - Service accounts (IAM bindings will be removed)"
    Write-Host ""
    Write-Host "This action is IRREVERSIBLE!" -ForegroundColor Yellow
    Write-Host ""
    
    $confirmation = Read-Host "Type 'DESTROY' to confirm"
    if ($confirmation -ne "DESTROY") {
        Write-Info "Destruction cancelled"
        exit 0
    }
    
    Write-Host ""
    $finalConfirm = Read-Host "Are you absolutely sure? (yes/no)"
    if ($finalConfirm -ne "yes") {
        Write-Info "Destruction cancelled"
        exit 0
    }
}

# ============================================================================
# STEP 1: Pre-Destroy Checks
# ============================================================================
Write-Step 1 "Pre-Destroy Checks"

# Check if Terraform state exists
if (-not (Test-Path "terraform.tfstate") -and -not (Test-Path ".terraform")) {
    Write-Warning "No Terraform state found. Nothing to destroy."
    exit 0
}

# Check Terraform is initialized
if (-not (Test-Path ".terraform")) {
    Write-Info "Initializing Terraform..."
    terraform init
}

# Show what will be destroyed
Write-Info "Resources to be destroyed:"
terraform state list 2>$null

# ============================================================================
# STEP 2: Remove kubectl context
# ============================================================================
Write-Step 2 "Remove kubectl Context"

$gkeCluster = terraform output -raw gke_cluster_name 2>$null
$gkeZone = terraform output -raw gke_cluster_location 2>$null

if ($gkeCluster) {
    Write-Info "Removing kubectl context for cluster: $gkeCluster"
    kubectl config delete-context "gke_${ProjectId}_${gkeZone}_${gkeCluster}" 2>$null
    kubectl config delete-cluster "gke_${ProjectId}_${gkeZone}_${gkeCluster}" 2>$null
    Write-Success "kubectl context removed"
} else {
    Write-Info "No GKE cluster context to remove"
}

# ============================================================================
# STEP 3: Terraform Destroy
# ============================================================================
Write-Step 3 "Terraform Destroy"

Write-Info "Running Terraform destroy..."

if ($AutoApprove) {
    terraform destroy -auto-approve
} else {
    terraform destroy
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Terraform destroy failed"
    exit 1
}

Write-Success "Terraform destroy complete"

# ============================================================================
# STEP 4: Cleanup Service Account Keys (Optional)
# ============================================================================
if ($CleanupSaKeys) {
    Write-Step 4 "Cleanup Service Account Keys"
    
    $saName = if ($env:SERVICE_ACCOUNT_NAME) { $env:SERVICE_ACCOUNT_NAME } else { "gke-jenkins-sa" }
    
    foreach ($suffix in @("gke", "jenkins")) {
        $saEmail = "$saName-$suffix@$ProjectId.iam.gserviceaccount.com"
        
        Write-Info "Checking for service account: $saEmail"
        
        $saExists = gcloud iam service-accounts describe $saEmail --project=$ProjectId 2>$null
        if ($saExists) {
            Write-Info "Deleting all keys for: $saEmail"
            
            # List and delete all user-managed keys
            $keys = gcloud iam service-accounts keys list `
                --iam-account=$saEmail `
                --project=$ProjectId `
                --format="value(name)" `
                --filter="keyType=USER_MANAGED" 2>$null
            
            foreach ($key in $keys) {
                if ($key) {
                    $keyId = Split-Path -Leaf $key
                    Write-Info "Deleting key: $keyId"
                    gcloud iam service-accounts keys delete $keyId `
                        --iam-account=$saEmail `
                        --project=$ProjectId `
                        --quiet 2>$null
                }
            }
            
            # Optionally delete the service account itself
            $response = Read-Host "Delete service account $saEmail? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                gcloud iam service-accounts delete $saEmail `
                    --project=$ProjectId `
                    --quiet 2>$null
                Write-Success "Service account deleted: $saEmail"
            }
        } else {
            Write-Info "Service account not found: $saEmail"
        }
    }
} else {
    Write-Step 4 "Cleanup Service Account Keys (SKIPPED)"
}

# ============================================================================
# STEP 5: Cleanup Local Files (Optional)
# ============================================================================
if ($CleanupLocal) {
    Write-Step 5 "Cleanup Local Files"
    
    # Remove Terraform files
    Write-Info "Removing Terraform state files..."
    Remove-Item -Path "terraform.tfstate" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "terraform.tfstate.backup" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "tfplan" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path ".terraform" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path ".terraform.lock.hcl" -Force -ErrorAction SilentlyContinue
    
    # Remove generated files
    Write-Info "Removing generated files..."
    Remove-Item -Path "terraform.tfvars" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "keys" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Success "Local files cleaned up"
} else {
    Write-Step 5 "Cleanup Local Files (SKIPPED)"
    Write-Info "Local files preserved. To clean up manually:"
    Write-Host "  Remove-Item terraform.tfstate, terraform.tfstate.backup, tfplan -Force"
    Write-Host "  Remove-Item .terraform -Recurse -Force"
    Write-Host "  Remove-Item terraform.tfvars -Force"
    Write-Host "  Remove-Item keys -Recurse -Force"
}

# ============================================================================
# Summary
# ============================================================================
Write-Step 6 "Cleanup Summary"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                    CLEANUP COMPLETE                            " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Resources destroyed:"
Write-Host "  - GKE Cluster"
Write-Host "  - Jenkins VM"
Write-Host "  - VPC Network and subnets"
Write-Host "  - Firewall rules"
Write-Host "  - Cloud NAT and Router"
Write-Host "  - Service accounts and IAM bindings"
Write-Host ""

if (-not $CleanupLocal) {
    Write-Host "Local files preserved:"
    Write-Host "  - terraform.tfstate (if exists)"
    Write-Host "  - .terraform directory"
    Write-Host "  - keys\ directory"
    Write-Host ""
}

Write-Success "All GCP resources have been destroyed!"
