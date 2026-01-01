#Requires -Version 5.1
<#
.SYNOPSIS
    Verification Script for Windows
    Verifies the infrastructure deployment is functional

.DESCRIPTION
    This script checks GKE cluster, Jenkins VM, service accounts, and networking
    to ensure the deployment is working correctly.

.EXAMPLE
    .\Verify.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Counters
$script:Passed = 0
$script:Failed = 0
$script:Warnings = 0

function Write-Header {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "     GCP GKE Jenkins Infrastructure - Verification (Windows)   " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "  $Message" -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Pass {
    param([string]$Message)
    Write-Host "[PASS] " -ForegroundColor Green -NoNewline
    Write-Host $Message
    $script:Passed++
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] " -ForegroundColor Red -NoNewline
    Write-Host $Message
    $script:Failed++
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
    $script:Warnings++
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

# Change to project directory
Set-Location $ProjectDir

Write-Header

# Load environment variables
if (Test-Path ".\.env.ps1") {
    . .\.env.ps1
}

$ProjectId = if ($env:GCP_PROJECT_ID) { $env:GCP_PROJECT_ID } else { "speedy-insight-483010-m3" }
$Zone = if ($env:GCP_ZONE) { $env:GCP_ZONE } else { "us-central1-a" }
$Region = if ($env:GCP_REGION) { $env:GCP_REGION } else { "us-central1" }

# Get Terraform outputs
$gkeCluster = $null
$gkeZone = $null
$jenkinsIp = $null
$jenkinsUrl = $null
$jenkinsVm = $null

if (Test-Path "terraform.tfstate") {
    $gkeCluster = terraform output -raw gke_cluster_name 2>$null
    $gkeZone = terraform output -raw gke_cluster_location 2>$null
    $jenkinsIp = terraform output -raw jenkins_external_ip 2>$null
    $jenkinsUrl = terraform output -raw jenkins_url 2>$null
    $jenkinsVm = terraform output -raw jenkins_vm_name 2>$null
} else {
    Write-Warn "No Terraform state found. Using environment variables."
    $gkeCluster = if ($env:GKE_CLUSTER_NAME) { $env:GKE_CLUSTER_NAME } else { "autopilot-cluster-1" }
    $gkeZone = $Zone
    $jenkinsVm = if ($env:JENKINS_VM_NAME) { $env:JENKINS_VM_NAME } else { "jenkins-server" }
}

# ============================================================================
# GCP Authentication Verification
# ============================================================================
Write-Section "GCP Authentication"

# Check gcloud authentication
$activeAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>$null | Select-Object -First 1
if ($activeAccount) {
    Write-Pass "gcloud authenticated as: $activeAccount"
} else {
    Write-Fail "gcloud is not authenticated"
}

# Check project access
$projectInfo = gcloud projects describe $ProjectId 2>$null
if ($projectInfo) {
    Write-Pass "Access to project: $ProjectId"
} else {
    Write-Fail "Cannot access project: $ProjectId"
}

# ============================================================================
# GKE Cluster Verification
# ============================================================================
Write-Section "GKE Cluster"

if ($gkeCluster) {
    # Check cluster exists
    $clusterInfo = gcloud container clusters describe $gkeCluster --zone=$gkeZone --project=$ProjectId 2>$null
    if ($clusterInfo) {
        Write-Pass "GKE cluster exists: $gkeCluster"
        
        # Get cluster status
        $clusterStatus = gcloud container clusters describe $gkeCluster `
            --zone=$gkeZone `
            --project=$ProjectId `
            --format="value(status)" 2>$null
        
        if ($clusterStatus -eq "RUNNING") {
            Write-Pass "GKE cluster status: RUNNING"
        } else {
            Write-Warn "GKE cluster status: $clusterStatus"
        }
        
        # Check node count
        $nodeCount = gcloud container clusters describe $gkeCluster `
            --zone=$gkeZone `
            --project=$ProjectId `
            --format="value(currentNodeCount)" 2>$null
        
        if ([int]$nodeCount -gt 0) {
            Write-Pass "GKE nodes running: $nodeCount"
        } else {
            Write-Warn "No GKE nodes running"
        }
    } else {
        Write-Fail "GKE cluster not found: $gkeCluster"
    }
    
    # Check kubectl connectivity
    Write-Info "Testing kubectl connectivity..."
    
    # Get credentials
    gcloud container clusters get-credentials $gkeCluster `
        --zone=$gkeZone `
        --project=$ProjectId 2>$null
    
    $kubectlInfo = kubectl cluster-info 2>$null
    if ($kubectlInfo) {
        Write-Pass "kubectl can connect to cluster"
        
        # Check nodes
        $readyNodes = (kubectl get nodes --no-headers 2>$null | Select-String "Ready").Count
        if ($readyNodes -gt 0) {
            Write-Pass "Kubernetes nodes ready: $readyNodes"
        } else {
            Write-Warn "No Kubernetes nodes in Ready state"
        }
        
        # Check system pods
        $runningPods = (kubectl get pods -n kube-system --no-headers 2>$null | Select-String "Running").Count
        if ($runningPods -gt 0) {
            Write-Pass "System pods running: $runningPods"
        } else {
            Write-Warn "No system pods running"
        }
    } else {
        Write-Fail "kubectl cannot connect to cluster"
    }
} else {
    Write-Warn "GKE cluster name not available"
}

# ============================================================================
# Jenkins VM Verification
# ============================================================================
Write-Section "Jenkins VM"

if ($jenkinsVm) {
    # Check VM exists
    $vmInfo = gcloud compute instances describe $jenkinsVm --zone=$Zone --project=$ProjectId 2>$null
    if ($vmInfo) {
        Write-Pass "Jenkins VM exists: $jenkinsVm"
        
        # Get VM status
        $vmStatus = gcloud compute instances describe $jenkinsVm `
            --zone=$Zone `
            --project=$ProjectId `
            --format="value(status)" 2>$null
        
        if ($vmStatus -eq "RUNNING") {
            Write-Pass "Jenkins VM status: RUNNING"
        } else {
            Write-Warn "Jenkins VM status: $vmStatus"
        }
        
        # Get external IP
        if (-not $jenkinsIp) {
            $jenkinsIp = gcloud compute instances describe $jenkinsVm `
                --zone=$Zone `
                --project=$ProjectId `
                --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>$null
        }
        
        if ($jenkinsIp) {
            Write-Pass "Jenkins external IP: $jenkinsIp"
        } else {
            Write-Warn "Jenkins has no external IP"
        }
    } else {
        Write-Fail "Jenkins VM not found: $jenkinsVm"
    }
    
    # Check Jenkins HTTP accessibility
    if ($jenkinsIp) {
        Write-Info "Testing Jenkins HTTP connectivity..."
        
        $jenkinsPort = if ($env:JENKINS_HTTP_PORT) { $env:JENKINS_HTTP_PORT } else { "8080" }
        $testUrl = "http://${jenkinsIp}:${jenkinsPort}/login"
        
        try {
            $response = Invoke-WebRequest -Uri $testUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            Write-Pass "Jenkins is accessible at: http://${jenkinsIp}:${jenkinsPort} (HTTP $($response.StatusCode))"
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 403) {
                Write-Pass "Jenkins is accessible at: http://${jenkinsIp}:${jenkinsPort} (HTTP 403 - authentication required)"
            } elseif ($statusCode -eq 503) {
                Write-Warn "Jenkins is starting up (HTTP 503). Try again in a few minutes."
            } else {
                Write-Warn "Jenkins may still be starting up. Check again in a few minutes."
            }
        }
    }
} else {
    Write-Warn "Jenkins VM name not available"
}

# ============================================================================
# Service Account Verification
# ============================================================================
Write-Section "Service Accounts"

$saName = if ($env:SERVICE_ACCOUNT_NAME) { $env:SERVICE_ACCOUNT_NAME } else { "gke-jenkins-sa" }

foreach ($suffix in @("gke", "jenkins")) {
    $saEmail = "$saName-$suffix@$ProjectId.iam.gserviceaccount.com"
    
    $saInfo = gcloud iam service-accounts describe $saEmail --project=$ProjectId 2>$null
    if ($saInfo) {
        Write-Pass "Service account exists: $saEmail"
        
        # Check for keys
        $keyCount = (gcloud iam service-accounts keys list `
            --iam-account=$saEmail `
            --project=$ProjectId `
            --format="value(name)" `
            --filter="keyType=USER_MANAGED" 2>$null | Measure-Object -Line).Lines
        
        if ($keyCount -gt 0) {
            Write-Pass "Service account has $keyCount user-managed key(s)"
        } else {
            Write-Info "Service account has no user-managed keys"
        }
    } else {
        Write-Fail "Service account not found: $saEmail"
    }
}

# Check local key file
$keyPath = if ($env:LOCAL_SA_KEY_PATH) { $env:LOCAL_SA_KEY_PATH } else { ".\keys\service-account-key.json" }
if (Test-Path $keyPath) {
    Write-Pass "Local service account key exists: $keyPath"
    
    # Validate key file
    try {
        $keyContent = Get-Content $keyPath | ConvertFrom-Json
        if ($keyContent.type -eq "service_account") {
            Write-Pass "Service account key is valid JSON"
        } else {
            Write-Warn "Service account key may be invalid"
        }
    } catch {
        Write-Warn "Could not parse service account key file"
    }
} else {
    Write-Info "Local service account key not found at: $keyPath"
}

# ============================================================================
# Network Verification
# ============================================================================
Write-Section "Networking"

$vpcName = if ($env:VPC_NETWORK_NAME) { $env:VPC_NETWORK_NAME } else { "gke-jenkins-vpc" }
$subnetName = if ($env:SUBNET_NAME) { $env:SUBNET_NAME } else { "gke-jenkins-subnet" }

# Check VPC
$vpcInfo = gcloud compute networks describe $vpcName --project=$ProjectId 2>$null
if ($vpcInfo) {
    Write-Pass "VPC network exists: $vpcName"
} else {
    Write-Fail "VPC network not found: $vpcName"
}

# Check subnet
$subnetInfo = gcloud compute networks subnets describe $subnetName --region=$Region --project=$ProjectId 2>$null
if ($subnetInfo) {
    Write-Pass "Subnet exists: $subnetName"
} else {
    Write-Fail "Subnet not found: $subnetName"
}

# Check firewall rules
$firewallCount = (gcloud compute firewall-rules list `
    --filter="network:$vpcName" `
    --project=$ProjectId `
    --format="value(name)" 2>$null | Measure-Object -Line).Lines

if ($firewallCount -gt 0) {
    Write-Pass "Firewall rules configured: $firewallCount rules"
} else {
    Write-Warn "No firewall rules found for VPC"
}

# ============================================================================
# Summary
# ============================================================================
Write-Section "Verification Summary"

Write-Host ""
$total = $script:Passed + $script:Failed + $script:Warnings
Write-Host "Total checks: $total"
Write-Host "  Passed:   $($script:Passed)" -ForegroundColor Green
Write-Host "  Failed:   $($script:Failed)" -ForegroundColor Red
Write-Host "  Warnings: $($script:Warnings)" -ForegroundColor Yellow
Write-Host ""

if ($script:Failed -eq 0) {
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "              ALL CRITICAL CHECKS PASSED                        " -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    
    if ($jenkinsUrl) {
        Write-Host ""
        Write-Host "Jenkins URL: $jenkinsUrl"
        Write-Host ""
        Write-Host "To get Jenkins initial admin password:"
        Write-Host "  gcloud compute ssh $jenkinsVm --zone=$Zone --command='sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
    }
    
    exit 0
} else {
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "              SOME CHECKS FAILED                                " -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review the failed checks above and take corrective action."
    exit 1
}
