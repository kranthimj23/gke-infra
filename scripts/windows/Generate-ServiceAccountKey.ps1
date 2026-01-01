#Requires -Version 5.1
<#
.SYNOPSIS
    Service Account Key Generation Script for Windows
    Creates a GCP service account and generates a JSON key file

.DESCRIPTION
    This script creates a GCP service account with appropriate IAM roles
    and generates a JSON key file for authentication.

.PARAMETER ProjectId
    GCP Project ID (default: from environment variable or mobile-app-1-482109)

.PARAMETER ServiceAccountName
    Service account name (default: gke-jenkins-sa)

.PARAMETER OutputPath
    Output path for key file (default: .\keys\service-account-key.json)

.EXAMPLE
    .\Generate-ServiceAccountKey.ps1
    .\Generate-ServiceAccountKey.ps1 -ProjectId "my-project" -ServiceAccountName "my-sa"
#>

[CmdletBinding()]
param(
    [string]$ProjectId = $env:GCP_PROJECT_ID,
    [string]$ServiceAccountName = $env:SERVICE_ACCOUNT_NAME,
    [string]$OutputPath = $env:LOCAL_SA_KEY_PATH
)

# Set defaults if not provided
if (-not $ProjectId) { $ProjectId = "mobile-app-1-482109" }
if (-not $ServiceAccountName) { $ServiceAccountName = "gke-jenkins-sa" }
if (-not $OutputPath) { $OutputPath = ".\keys\service-account-key.json" }

# IAM roles for the service account
$IamRoles = @(
    "roles/container.developer",
    "roles/container.clusterViewer",
    "roles/storage.admin",
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/compute.instanceAdmin.v1",
    "roles/iam.serviceAccountUser"
)

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "==============================================" -ForegroundColor Blue
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

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

Write-Header "Service Account Key Generation (Windows)"

# Validate gcloud is installed
Write-Info "Validating gcloud CLI..."
if (-not (Get-Command "gcloud" -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI is not installed. Please install it first."
    exit 1
}

# Check authentication
$activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null | Select-Object -First 1
if (-not $activeAccount) {
    Write-Error "gcloud is not authenticated. Please run: gcloud auth login"
    exit 1
}

# Set project
Write-Info "Setting project to: $ProjectId"
gcloud config set project $ProjectId 2>$null

# Create output directory
$keyDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $keyDir)) {
    Write-Info "Creating directory: $keyDir"
    New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
}

# Full service account email
$saEmail = "$ServiceAccountName@$ProjectId.iam.gserviceaccount.com"

Write-Header "Creating Service Account"

# Check if service account exists
$saExists = gcloud iam service-accounts describe $saEmail --project=$ProjectId 2>$null
if ($saExists) {
    Write-Info "Service account already exists: $saEmail"
} else {
    Write-Info "Creating service account: $ServiceAccountName"
    gcloud iam service-accounts create $ServiceAccountName `
        --display-name="GKE Jenkins Service Account" `
        --description="Service account for GKE and Jenkins CI/CD operations" `
        --project=$ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Service account created: $saEmail"
    } else {
        Write-Error "Failed to create service account"
        exit 1
    }
}

Write-Header "Assigning IAM Roles"

foreach ($role in $IamRoles) {
    Write-Info "Assigning role: $role"
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$saEmail" `
        --role=$role `
        --condition=None `
        --quiet 2>$null
}

Write-Success "All IAM roles assigned"

Write-Header "Generating Service Account Key"

# Generate new key
Write-Info "Generating new key file: $OutputPath"
gcloud iam service-accounts keys create $OutputPath `
    --iam-account=$saEmail `
    --project=$ProjectId

if ($LASTEXITCODE -eq 0) {
    Write-Success "Service account key generated: $OutputPath"
} else {
    Write-Error "Failed to generate service account key"
    exit 1
}

Write-Header "Summary"

Write-Host ""
Write-Host "Service Account Details:"
Write-Host "  Email: $saEmail"
Write-Host "  Key Path: $OutputPath"
Write-Host ""
Write-Host "To use this key:"
Write-Host "  `$env:GOOGLE_APPLICATION_CREDENTIALS = `"$((Resolve-Path $OutputPath).Path)`""
Write-Host ""
Write-Host "To activate the service account:"
Write-Host "  gcloud auth activate-service-account --key-file=`"$OutputPath`""
Write-Host ""

Write-Success "Service account key generation complete!"
