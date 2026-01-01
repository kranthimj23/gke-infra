#Requires -Version 5.1
<#
.SYNOPSIS
    Prerequisites Validation Script for Windows
    Validates all required tools and configurations for GCP GKE Jenkins infrastructure

.DESCRIPTION
    This script checks for required tools (Terraform, gcloud, kubectl, Git, Python)
    and validates GCP authentication and project access.

.EXAMPLE
    .\Validate-Prerequisites.ps1
#>

[CmdletBinding()]
param()

# Minimum versions
$MinTerraformVersion = [Version]"1.5.0"
$MinGcloudVersion = [Version]"450.0.0"
$MinKubectlVersion = [Version]"1.28.0"
$MinGitVersion = [Version]"2.40.0"
$MinPythonVersion = [Version]"3.11"

# Counters
$script:Errors = 0
$script:Warnings = 0

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
    $script:Errors++
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
    $script:Warnings++
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Test-Command {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-VersionFromString {
    param([string]$VersionString)
    $match = [regex]::Match($VersionString, '\d+\.\d+\.\d+')
    if ($match.Success) {
        return [Version]$match.Value
    }
    return $null
}

Write-Header "GCP GKE Jenkins Infrastructure - Prerequisites Validation (Windows)"

# Check Terraform
Write-Header "Checking Terraform"
if (Test-Command "terraform") {
    $terraformOutput = terraform version 2>&1 | Select-Object -First 1
    $terraformVersion = Get-VersionFromString $terraformOutput
    if ($terraformVersion -ge $MinTerraformVersion) {
        Write-Success "Terraform $terraformVersion installed (minimum: $MinTerraformVersion)"
    } else {
        Write-Error "Terraform $terraformVersion is below minimum version $MinTerraformVersion"
    }
} else {
    Write-Error "Terraform is not installed"
    Write-Info "Install with: choco install terraform"
    Write-Info "Or download from: https://developer.hashicorp.com/terraform/downloads"
}

# Check gcloud CLI
Write-Header "Checking Google Cloud SDK"
if (Test-Command "gcloud") {
    $gcloudOutput = gcloud version 2>&1 | Select-Object -First 1
    $gcloudVersion = Get-VersionFromString $gcloudOutput
    if ($gcloudVersion -ge $MinGcloudVersion) {
        Write-Success "gcloud CLI $gcloudVersion installed (minimum: $MinGcloudVersion)"
    } else {
        Write-Warning "gcloud CLI $gcloudVersion may be below recommended version $MinGcloudVersion"
    }
    
    # Check gcloud authentication
    $activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null | Select-Object -First 1
    if ($activeAccount) {
        Write-Success "gcloud authenticated as: $activeAccount"
    } else {
        Write-Warning "gcloud is not authenticated. Run: gcloud auth login"
    }
    
    # Check current project
    $currentProject = gcloud config get-value project 2>$null
    if ($currentProject) {
        Write-Success "gcloud project set to: $currentProject"
    } else {
        Write-Warning "No gcloud project set. Run: gcloud config set project PROJECT_ID"
    }
} else {
    Write-Error "gcloud CLI is not installed"
    Write-Info "Download from: https://cloud.google.com/sdk/docs/install"
}

# Check kubectl
Write-Header "Checking kubectl"
if (Test-Command "kubectl") {
    $kubectlOutput = kubectl version --client 2>&1 | Select-Object -First 1
    $kubectlVersion = Get-VersionFromString $kubectlOutput
    if ($kubectlVersion -ge $MinKubectlVersion) {
        Write-Success "kubectl $kubectlVersion installed (minimum: $MinKubectlVersion)"
    } else {
        Write-Warning "kubectl $kubectlVersion may be below recommended version $MinKubectlVersion"
    }
} else {
    Write-Error "kubectl is not installed"
    Write-Info "Install with: choco install kubernetes-cli"
}

# Check Git
Write-Header "Checking Git"
if (Test-Command "git") {
    $gitOutput = git --version 2>&1
    $gitVersion = Get-VersionFromString $gitOutput
    if ($gitVersion -ge $MinGitVersion) {
        Write-Success "Git $gitVersion installed (minimum: $MinGitVersion)"
    } else {
        Write-Warning "Git $gitVersion may be below recommended version $MinGitVersion"
    }
} else {
    Write-Error "Git is not installed"
    Write-Info "Install with: choco install git"
}

# Check Python
Write-Header "Checking Python"
$pythonCmd = $null
if (Test-Command "python") {
    $pythonCmd = "python"
} elseif (Test-Command "python3") {
    $pythonCmd = "python3"
}

if ($pythonCmd) {
    $pythonOutput = & $pythonCmd --version 2>&1
    $pythonVersion = Get-VersionFromString $pythonOutput
    if ($pythonVersion -ge $MinPythonVersion) {
        Write-Success "Python $pythonVersion installed (minimum: $MinPythonVersion)"
    } else {
        Write-Warning "Python $pythonVersion is below recommended version $MinPythonVersion"
    }
} else {
    Write-Error "Python is not installed"
    Write-Info "Install with: choco install python311"
    Write-Info "Or download from: https://www.python.org/downloads/"
}

# Check environment variables
Write-Header "Checking Environment Variables"
if (Test-Path ".\.env.ps1") {
    Write-Success ".env.ps1 file found"
} elseif (Test-Path ".\.env") {
    Write-Warning ".env file found (bash format). Consider using .env.ps1 for PowerShell"
} else {
    Write-Warning "No environment file found. Copy .env.example.ps1 to .env.ps1 and configure"
}

if ($env:GCP_PROJECT_ID) {
    Write-Success "GCP_PROJECT_ID is set: $env:GCP_PROJECT_ID"
} else {
    Write-Warning "GCP_PROJECT_ID environment variable not set"
}

if ($env:GCP_REGION) {
    Write-Success "GCP_REGION is set: $env:GCP_REGION"
} else {
    Write-Warning "GCP_REGION environment variable not set"
}

if ($env:GOOGLE_APPLICATION_CREDENTIALS) {
    if (Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS) {
        Write-Success "GOOGLE_APPLICATION_CREDENTIALS file exists: $env:GOOGLE_APPLICATION_CREDENTIALS"
    } else {
        Write-Warning "GOOGLE_APPLICATION_CREDENTIALS set but file not found: $env:GOOGLE_APPLICATION_CREDENTIALS"
    }
} else {
    Write-Warning "GOOGLE_APPLICATION_CREDENTIALS not set (required for service account auth)"
}

# Summary
Write-Header "Validation Summary"
Write-Host ""
if ($script:Errors -eq 0 -and $script:Warnings -eq 0) {
    Write-Host "All prerequisites validated successfully!" -ForegroundColor Green
    exit 0
} elseif ($script:Errors -eq 0) {
    Write-Host "Validation completed with $($script:Warnings) warning(s)." -ForegroundColor Yellow
    Write-Host "Review warnings above and address if needed."
    exit 0
} else {
    Write-Host "Validation failed with $($script:Errors) error(s) and $($script:Warnings) warning(s)." -ForegroundColor Red
    Write-Host "Please install missing prerequisites before proceeding."
    exit 1
}
