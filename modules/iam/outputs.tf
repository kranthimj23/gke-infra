# IAM Module - Outputs

output "gke_node_sa_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_node_sa.email
}

output "gke_node_sa_name" {
  description = "Name of the GKE node service account"
  value       = google_service_account.gke_node_sa.name
}

output "jenkins_sa_email" {
  description = "Email of the Jenkins service account"
  value       = google_service_account.jenkins_sa.email
}

output "jenkins_sa_name" {
  description = "Name of the Jenkins service account"
  value       = google_service_account.jenkins_sa.name
}

output "jenkins_sa_key_private" {
  description = "Private key for Jenkins service account (base64 encoded)"
  value       = google_service_account_key.jenkins_key.private_key
  sensitive   = true
}

output "jenkins_sa_key_id" {
  description = "ID of the Jenkins service account key"
  value       = google_service_account_key.jenkins_key.id
}
