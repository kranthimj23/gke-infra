# Terraform Variables
# All infrastructure parameters configurable via environment variables

# =============================================================================
# GCP Project Configuration
# =============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "mobile-app-1-482109"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

# =============================================================================
# Networking Configuration
# =============================================================================

variable "vpc_network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "gke-jenkins-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "gke-jenkins-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "gke_pods_cidr_name" {
  description = "Name of the secondary range for GKE pods"
  type        = string
  default     = "gke-pods"
}

variable "gke_pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "gke_services_cidr_name" {
  description = "Name of the secondary range for GKE services"
  type        = string
  default     = "gke-services"
}

variable "gke_services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/20"
}

# =============================================================================
# GKE Cluster Configuration
# =============================================================================

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "autopilot-cluster-1"
}

variable "gke_cluster_version" {
  description = "GKE cluster version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "gke_node_pool_name" {
  description = "Name of the GKE node pool"
  type        = string
  default     = "default-pool"
}

variable "gke_node_count" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "gke_min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "gke_max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "gke_node_disk_size_gb" {
  description = "Disk size in GB for GKE nodes"
  type        = number
  default     = 50
}

variable "gke_node_disk_type" {
  description = "Disk type for GKE nodes"
  type        = string
  default     = "pd-standard"
}

variable "gke_preemptible_nodes" {
  description = "Use preemptible VMs for GKE nodes (cost optimization)"
  type        = bool
  default     = true
}

variable "gke_deletion_protection" {
  description = "Enable deletion protection for GKE cluster"
  type        = bool
  default     = false
}

variable "gke_master_authorized_networks" {
  description = "List of authorized networks for GKE master access"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  ]
}

# =============================================================================
# Jenkins VM Configuration
# =============================================================================

variable "jenkins_vm_name" {
  description = "Name of the Jenkins VM"
  type        = string
  default     = "jenkins-server"
}

variable "jenkins_machine_type" {
  description = "Machine type for Jenkins VM"
  type        = string
  default     = "e2-medium"
}

variable "jenkins_disk_size_gb" {
  description = "Disk size in GB for Jenkins VM"
  type        = number
  default     = 50
}

variable "jenkins_disk_type" {
  description = "Disk type for Jenkins VM"
  type        = string
  default     = "pd-standard"
}

variable "jenkins_preemptible" {
  description = "Use preemptible VM for Jenkins (cost optimization, not recommended for production)"
  type        = bool
  default     = false
}

variable "jenkins_http_port" {
  description = "Jenkins HTTP port"
  type        = number
  default     = 8080
}

variable "jenkins_jnlp_port" {
  description = "Jenkins JNLP port for agents"
  type        = number
  default     = 50000
}

variable "jenkins_allowed_ips" {
  description = "List of IP ranges allowed to access Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# =============================================================================
# Service Account Configuration
# =============================================================================

variable "service_account_name" {
  description = "Base name for service accounts"
  type        = string
  default     = "gke-jenkins-sa"
}

variable "service_account_key_path" {
  description = "Path to store service account key on Jenkins VM"
  type        = string
  default     = "/var/lib/jenkins/keys/mobile-app-1-482109-e631e1327727.json"
}

variable "local_sa_key_path" {
  description = "Local path to save service account key"
  type        = string
  default     = "./keys/service-account-key.json"
}

variable "save_sa_key_locally" {
  description = "Save service account key to local file"
  type        = bool
  default     = true
}

# =============================================================================
# Python Configuration
# =============================================================================

variable "python_version" {
  description = "Python version to install on Jenkins VM"
  type        = string
  default     = "3.11"
}

# =============================================================================
# Labels and Tags
# =============================================================================

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "development"
}

variable "team" {
  description = "Team label"
  type        = string
  default     = "devops"
}

variable "application" {
  description = "Application label"
  type        = string
  default     = "jenkins-cicd"
}

# =============================================================================
# Terraform State Configuration (Optional)
# =============================================================================

variable "tf_state_bucket" {
  description = "GCS bucket for Terraform state (optional)"
  type        = string
  default     = ""
}

variable "tf_state_prefix" {
  description = "Prefix for Terraform state in GCS bucket"
  type        = string
  default     = "terraform/state"
}
