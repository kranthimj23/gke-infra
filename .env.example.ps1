# GCP GKE Jenkins Infrastructure - Environment Variables (PowerShell)
# Copy this file to .env.ps1 and configure the values
# Usage: . .\.env.ps1

# =============================================================================
# GCP Project Configuration
# =============================================================================

# GCP Project ID (required)
$env:GCP_PROJECT_ID = "mobile-app-1-482109"

# GCP Region for resources
$env:GCP_REGION = "us-central1"

# GCP Zone for zonal resources (GKE cluster, Jenkins VM)
$env:GCP_ZONE = "us-central1-a"

# =============================================================================
# GKE Cluster Configuration
# =============================================================================

# GKE Cluster name
$env:GKE_CLUSTER_NAME = "autopilot-cluster-1"

# GKE Cluster version (leave empty for latest stable)
$env:GKE_CLUSTER_VERSION = ""

# GKE Node pool configuration
$env:GKE_NODE_POOL_NAME = "default-pool"
$env:GKE_NODE_COUNT = "2"
$env:GKE_MIN_NODE_COUNT = "1"
$env:GKE_MAX_NODE_COUNT = "5"
$env:GKE_NODE_MACHINE_TYPE = "e2-medium"
$env:GKE_NODE_DISK_SIZE_GB = "50"
$env:GKE_NODE_DISK_TYPE = "pd-standard"

# Enable preemptible nodes for cost savings (true/false)
$env:GKE_PREEMPTIBLE_NODES = "true"

# =============================================================================
# Jenkins VM Configuration
# =============================================================================

# Jenkins VM name
$env:JENKINS_VM_NAME = "jenkins-server"

# Jenkins VM machine type
$env:JENKINS_MACHINE_TYPE = "e2-medium"

# Jenkins VM disk size in GB
$env:JENKINS_DISK_SIZE_GB = "50"

# Jenkins VM disk type (pd-standard, pd-ssd, pd-balanced)
$env:JENKINS_DISK_TYPE = "pd-standard"

# Enable preemptible VM for cost savings (true/false)
# WARNING: Preemptible VMs can be terminated at any time
$env:JENKINS_PREEMPTIBLE = "false"

# Jenkins HTTP port
$env:JENKINS_HTTP_PORT = "8080"

# Jenkins JNLP port (for agents)
$env:JENKINS_JNLP_PORT = "50000"

# =============================================================================
# Networking Configuration
# =============================================================================

# VPC Network name
$env:VPC_NETWORK_NAME = "gke-jenkins-vpc"

# Subnet name
$env:SUBNET_NAME = "gke-jenkins-subnet"

# Subnet CIDR range
$env:SUBNET_CIDR = "10.0.0.0/24"

# GKE Pods secondary range
$env:GKE_PODS_CIDR_NAME = "gke-pods"
$env:GKE_PODS_CIDR = "10.1.0.0/16"

# GKE Services secondary range
$env:GKE_SERVICES_CIDR_NAME = "gke-services"
$env:GKE_SERVICES_CIDR = "10.2.0.0/20"

# =============================================================================
# Service Account Configuration
# =============================================================================

# Service account name for GKE and Jenkins
$env:SERVICE_ACCOUNT_NAME = "gke-jenkins-sa"

# Service account key path (on Jenkins VM)
$env:SERVICE_ACCOUNT_KEY_PATH = "/var/lib/jenkins/keys/mobile-app-1-482109-e631e1327727.json"

# Local path for service account key (during provisioning)
$env:LOCAL_SA_KEY_PATH = ".\keys\service-account-key.json"

# =============================================================================
# Repository Configuration
# =============================================================================

# Source repository URL
$env:SOURCE_REPO_URL = "https://github.com/kranthimj23/zdt-manager-src"

# Source repository branch
$env:SOURCE_REPO_BRANCH = "zdt-application"

# =============================================================================
# Labels and Tags
# =============================================================================

# Environment label
$env:ENVIRONMENT = "development"

# Team label
$env:TEAM = "devops"

# Application label
$env:APPLICATION = "jenkins-cicd"

# =============================================================================
# Python Configuration
# =============================================================================

$env:PYTHON_VERSION = "3.11"

Write-Host "Environment variables loaded successfully!" -ForegroundColor Green
