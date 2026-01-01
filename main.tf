# Main Terraform Configuration
# GCP GKE Jenkins Infrastructure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  # Uncomment to use remote state storage
  # backend "gcs" {
  #   bucket = var.tf_state_bucket
  #   prefix = var.tf_state_prefix
  # }
}

# Google Provider Configuration
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "servicenetworking.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_id         = var.project_id
  region             = var.region
  vpc_name           = var.vpc_network_name
  subnet_name        = var.subnet_name
  subnet_cidr        = var.subnet_cidr
  pods_cidr_name     = var.gke_pods_cidr_name
  pods_cidr          = var.gke_pods_cidr
  services_cidr_name = var.gke_services_cidr_name
  services_cidr      = var.gke_services_cidr
  jenkins_http_port  = var.jenkins_http_port
  jenkins_jnlp_port  = var.jenkins_jnlp_port
  jenkins_allowed_ips = var.jenkins_allowed_ips

  depends_on = [google_project_service.required_apis]
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_id           = var.project_id
  service_account_name = var.service_account_name

  depends_on = [google_project_service.required_apis]
}

# GKE Cluster Module
module "gke" {
  source = "./modules/gke"

  project_id           = var.project_id
  zone                 = var.zone
  cluster_name         = var.gke_cluster_name
  cluster_version      = var.gke_cluster_version
  vpc_self_link        = module.networking.vpc_self_link
  subnet_self_link     = module.networking.subnet_self_link
  pods_cidr_name       = module.networking.pods_cidr_name
  services_cidr_name   = module.networking.services_cidr_name
  node_pool_name       = var.gke_node_pool_name
  node_count           = var.gke_node_count
  min_node_count       = var.gke_min_node_count
  max_node_count       = var.gke_max_node_count
  machine_type         = var.gke_node_machine_type
  disk_size_gb         = var.gke_node_disk_size_gb
  disk_type            = var.gke_node_disk_type
  preemptible          = var.gke_preemptible_nodes
  node_service_account = module.iam.gke_node_sa_email
  deletion_protection  = var.gke_deletion_protection

  master_authorized_networks = var.gke_master_authorized_networks

  labels = local.common_labels

  depends_on = [
    module.networking,
    module.iam
  ]
}

# Jenkins VM Module
module "jenkins" {
  source = "./modules/jenkins"

  project_id                 = var.project_id
  region                     = var.region
  zone                       = var.zone
  vm_name                    = var.jenkins_vm_name
  machine_type               = var.jenkins_machine_type
  disk_size_gb               = var.jenkins_disk_size_gb
  disk_type                  = var.jenkins_disk_type
  preemptible                = var.jenkins_preemptible
  vpc_self_link              = module.networking.vpc_self_link
  subnet_self_link           = module.networking.subnet_self_link
  service_account_email      = module.iam.jenkins_sa_email
  service_account_key_base64 = module.iam.jenkins_sa_key_private
  sa_key_path                = var.service_account_key_path
  jenkins_http_port          = var.jenkins_http_port
  jenkins_jnlp_port          = var.jenkins_jnlp_port
  gke_cluster_name           = module.gke.cluster_name
  gke_cluster_zone           = var.zone
  python_version             = var.python_version

  labels = local.common_labels

  depends_on = [
    module.networking,
    module.iam,
    module.gke
  ]
}

# Local values
locals {
  common_labels = {
    environment = var.environment
    team        = var.team
    application = var.application
    managed_by  = "terraform"
  }
}

# Save service account key to local file
resource "local_file" "jenkins_sa_key" {
  count = var.save_sa_key_locally ? 1 : 0

  content         = base64decode(module.iam.jenkins_sa_key_private)
  filename        = var.local_sa_key_path
  file_permission = "0600"
}
