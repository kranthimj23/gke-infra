# Networking Module - VPC, Subnets, and Firewall Rules
# This module creates the network infrastructure for GKE and Jenkins

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC network for GKE cluster and Jenkins VM"
}

# Primary Subnet for GKE and Jenkins
resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  # Secondary IP ranges for GKE pods and services
  secondary_ip_range {
    range_name    = var.pods_cidr_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.services_cidr_name
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# Cloud NAT for outbound internet access from private nodes
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rule - Allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    var.subnet_cidr,
    var.pods_cidr,
    var.services_cidr
  ]

  priority = 1000
}

# Firewall rule - Allow SSH from IAP
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.vpc_name}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP IP range
  source_ranges = ["35.235.240.0/20"]

  target_tags = ["allow-ssh"]
  priority    = 1000
}

# Firewall rule - Allow Jenkins HTTP/HTTPS
resource "google_compute_firewall" "allow_jenkins" {
  name    = "${var.vpc_name}-allow-jenkins"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = [var.jenkins_http_port, "443"]
  }

  source_ranges = var.jenkins_allowed_ips

  target_tags = ["jenkins"]
  priority    = 1000
}

# Firewall rule - Allow Jenkins JNLP for agents
resource "google_compute_firewall" "allow_jenkins_jnlp" {
  name    = "${var.vpc_name}-allow-jenkins-jnlp"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = [var.jenkins_jnlp_port]
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr]

  target_tags = ["jenkins"]
  priority    = 1000
}

# Firewall rule - Allow health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.vpc_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  # Google health check IP ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["gke-node", "jenkins"]
  priority    = 1000
}
