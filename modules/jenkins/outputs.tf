# Jenkins Module - Outputs

output "instance_id" {
  description = "The ID of the Jenkins VM instance"
  value       = google_compute_instance.jenkins.instance_id
}

output "instance_name" {
  description = "The name of the Jenkins VM instance"
  value       = google_compute_instance.jenkins.name
}

output "instance_self_link" {
  description = "The self link of the Jenkins VM instance"
  value       = google_compute_instance.jenkins.self_link
}

output "internal_ip" {
  description = "The internal IP address of the Jenkins VM"
  value       = google_compute_instance.jenkins.network_interface[0].network_ip
}

output "external_ip" {
  description = "The external IP address of the Jenkins VM"
  value       = google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip
}

output "static_ip" {
  description = "The static external IP address (if created)"
  value       = var.create_static_ip ? google_compute_address.jenkins_ip[0].address : null
}

output "jenkins_url" {
  description = "The URL to access Jenkins"
  value       = "http://${google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip}:${var.jenkins_http_port}"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins VM"
  value       = "gcloud compute ssh ${google_compute_instance.jenkins.name} --zone ${var.zone} --project ${var.project_id}"
}

output "zone" {
  description = "The zone where Jenkins VM is deployed"
  value       = google_compute_instance.jenkins.zone
}
