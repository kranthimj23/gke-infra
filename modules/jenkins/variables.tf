# Jenkins Module - Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "vm_name" {
  description = "Name of the Jenkins VM"
  type        = string
  default     = "jenkins-server"
}

variable "machine_type" {
  description = "Machine type for Jenkins VM"
  type        = string
  default     = "e2-medium"
}

variable "boot_image" {
  description = "Boot image for Jenkins VM"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "disk_type" {
  description = "Boot disk type (pd-standard, pd-ssd, pd-balanced)"
  type        = string
  default     = "pd-standard"
}

variable "preemptible" {
  description = "Use preemptible/spot VM for cost savings"
  type        = bool
  default     = false
}

variable "vpc_self_link" {
  description = "Self link of the VPC network"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for Jenkins VM"
  type        = string
}

variable "service_account_key_base64" {
  description = "Base64 encoded service account key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sa_key_path" {
  description = "Path to store service account key on VM"
  type        = string
  default     = "/var/lib/jenkins/keys/service-account.json"
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

variable "gke_cluster_name" {
  description = "GKE cluster name for kubectl configuration"
  type        = string
  default     = ""
}

variable "gke_cluster_zone" {
  description = "GKE cluster zone for kubectl configuration"
  type        = string
  default     = ""
}

variable "install_docker" {
  description = "Install Docker on Jenkins VM"
  type        = bool
  default     = true
}

variable "install_kubectl" {
  description = "Install kubectl on Jenkins VM"
  type        = bool
  default     = true
}

variable "install_gcloud" {
  description = "Install Google Cloud SDK on Jenkins VM"
  type        = bool
  default     = true
}

variable "python_version" {
  description = "Python version to install"
  type        = string
  default     = "3.11"
}

variable "create_static_ip" {
  description = "Create a static external IP for Jenkins"
  type        = bool
  default     = true
}

variable "network_tier" {
  description = "Network tier for external IP (PREMIUM or STANDARD)"
  type        = string
  default     = "STANDARD"
}

variable "create_health_check" {
  description = "Create a health check for Jenkins"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
