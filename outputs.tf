# Terraform Outputs
# All important values from the infrastructure deployment

# =============================================================================
# Networking Outputs
# =============================================================================

output "vpc_name" {
  description = "Name of the VPC network"
  value       = module.networking.vpc_name
}

output "vpc_self_link" {
  description = "Self link of the VPC network"
  value       = module.networking.vpc_self_link
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = module.networking.subnet_name
}

output "subnet_cidr" {
  description = "CIDR range of the subnet"
  value       = module.networking.subnet_cidr
}

# =============================================================================
# IAM Outputs
# =============================================================================

output "gke_node_service_account" {
  description = "Email of the GKE node service account"
  value       = module.iam.gke_node_sa_email
}

output "jenkins_service_account" {
  description = "Email of the Jenkins service account"
  value       = module.iam.jenkins_sa_email
}

# =============================================================================
# GKE Cluster Outputs
# =============================================================================

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_location" {
  description = "Location of the GKE cluster"
  value       = module.gke.cluster_location
}

output "gke_cluster_master_version" {
  description = "Master version of the GKE cluster"
  value       = module.gke.cluster_master_version
}

output "gke_get_credentials_command" {
  description = "Command to get GKE cluster credentials"
  value       = module.gke.get_credentials_command
}

# =============================================================================
# Jenkins VM Outputs
# =============================================================================

output "jenkins_vm_name" {
  description = "Name of the Jenkins VM"
  value       = module.jenkins.instance_name
}

output "jenkins_internal_ip" {
  description = "Internal IP of the Jenkins VM"
  value       = module.jenkins.internal_ip
}

output "jenkins_external_ip" {
  description = "External IP of the Jenkins VM"
  value       = module.jenkins.external_ip
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = module.jenkins.jenkins_url
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins VM"
  value       = module.jenkins.ssh_command
}

# =============================================================================
# Connection Information
# =============================================================================

output "connection_info" {
  description = "Connection information for the infrastructure"
  value = <<-EOT
    
    ============================================
    GCP GKE Jenkins Infrastructure - Connection Info
    ============================================
    
    GKE Cluster:
      Name: ${module.gke.cluster_name}
      Zone: ${module.gke.cluster_location}
      Get credentials: ${module.gke.get_credentials_command}
    
    Jenkins:
      URL: ${module.jenkins.jenkins_url}
      SSH: ${module.jenkins.ssh_command}
      External IP: ${module.jenkins.external_ip}
    
    Service Accounts:
      GKE Nodes: ${module.iam.gke_node_sa_email}
      Jenkins: ${module.iam.jenkins_sa_email}
    
    ============================================
  EOT
}

# =============================================================================
# Environment Variables Export
# =============================================================================

output "environment_variables" {
  description = "Environment variables for CI/CD pipelines"
  value = {
    GCP_PROJECT_ID     = var.project_id
    GCP_REGION         = var.region
    GCP_ZONE           = var.zone
    GKE_CLUSTER_NAME   = module.gke.cluster_name
    GKE_CLUSTER_ZONE   = module.gke.cluster_location
    JENKINS_URL        = module.jenkins.jenkins_url
    JENKINS_EXTERNAL_IP = module.jenkins.external_ip
  }
}
