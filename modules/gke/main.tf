# GKE Module - Standard GKE Cluster with Cost Optimization
# This module creates a standard (non-Autopilot) GKE cluster

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = var.vpc_self_link
  subnetwork = var.subnet_self_link

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_cidr_name
    services_secondary_range_name = var.services_cidr_name
  }

  # Private cluster configuration for security
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Master authorized networks
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Cluster addons
  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    network_policy_config {
      disabled = !var.enable_network_policy
    }

    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Maintenance window for cost optimization (off-peak hours)
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  # Resource labels
  resource_labels = var.labels

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Timeouts
  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }

  lifecycle {
    ignore_changes = [
      node_pool,
      initial_node_count
    ]
  }
}

# Primary Node Pool with cost optimization
resource "google_container_node_pool" "primary_nodes" {
  name       = var.node_pool_name
  project    = var.project_id
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  # Autoscaling configuration
  autoscaling {
    min_node_count  = var.min_node_count
    max_node_count  = var.max_node_count
    location_policy = "BALANCED"
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  # Node configuration
  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type

    # Use preemptible/spot VMs for cost savings
    preemptible = var.preemptible
    spot        = var.use_spot_vms

    # Service account
    service_account = var.node_service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = merge(var.labels, {
      "node-pool" = var.node_pool_name
    })

    # Tags for firewall rules
    tags = ["gke-node", "${var.cluster_name}-node"]

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Workload metadata config
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# Optional: Spot/Preemptible node pool for batch workloads
resource "google_container_node_pool" "spot_nodes" {
  count = var.create_spot_node_pool ? 1 : 0

  name       = "${var.node_pool_name}-spot"
  project    = var.project_id
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 0

  autoscaling {
    min_node_count  = 0
    max_node_count  = var.spot_max_node_count
    location_policy = "ANY"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.spot_machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    spot         = true

    service_account = var.node_service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = merge(var.labels, {
      "node-pool" = "${var.node_pool_name}-spot"
      "spot"      = "true"
    })

    tags = ["gke-node", "${var.cluster_name}-node", "spot"]

    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
