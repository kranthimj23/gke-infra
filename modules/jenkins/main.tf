# Jenkins Module - Jenkins VM with Cost Optimization
# This module creates a Jenkins server VM with optional preemptible configuration

# Static external IP for Jenkins (optional)
resource "google_compute_address" "jenkins_ip" {
  count = var.create_static_ip ? 1 : 0

  name         = "${var.vm_name}-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = var.network_tier
}

# Jenkins VM Instance
resource "google_compute_instance" "jenkins" {
  name         = var.vm_name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  # Preemptible/Spot configuration for cost savings
  scheduling {
    preemptible                 = var.preemptible
    automatic_restart           = var.preemptible ? false : true
    on_host_maintenance         = var.preemptible ? "TERMINATE" : "MIGRATE"
    provisioning_model          = var.preemptible ? "SPOT" : "STANDARD"
    instance_termination_action = var.preemptible ? "STOP" : null
  }

  # Boot disk
  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.disk_size_gb
      type  = var.disk_type
    }
    auto_delete = true
  }

  # Network interface
  network_interface {
    network    = var.vpc_self_link
    subnetwork = var.subnet_self_link

    access_config {
      nat_ip       = var.create_static_ip ? google_compute_address.jenkins_ip[0].address : null
      network_tier = var.network_tier
    }
  }

  # Service account
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  # Tags for firewall rules
  tags = ["jenkins", "allow-ssh"]

  # Labels
  labels = var.labels

  # Metadata
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Startup script to install Jenkins and dependencies
  metadata_startup_script = templatefile("${path.module}/templates/startup.sh", {
    jenkins_http_port     = var.jenkins_http_port
    jenkins_jnlp_port     = var.jenkins_jnlp_port
    gke_cluster_name      = var.gke_cluster_name
    gke_cluster_zone      = var.gke_cluster_zone
    project_id            = var.project_id
    service_account_key   = var.service_account_key_base64
    sa_key_path           = var.sa_key_path
    install_docker        = var.install_docker
    install_kubectl       = var.install_kubectl
    install_gcloud        = var.install_gcloud
    python_version        = var.python_version
  })

  # Shielded VM configuration
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # Allow stopping for updates
  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      metadata_startup_script
    ]
  }
}

# Firewall rule for Jenkins health check (if using load balancer)
resource "google_compute_health_check" "jenkins" {
  count = var.create_health_check ? 1 : 0

  name    = "${var.vm_name}-health-check"
  project = var.project_id

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = var.jenkins_http_port
    request_path = "/login"
  }
}
