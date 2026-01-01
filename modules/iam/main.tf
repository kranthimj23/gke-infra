# IAM Module - Service Accounts and IAM Bindings
# This module creates service accounts for GKE and Jenkins operations

# Service Account for GKE nodes
resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.service_account_name}-gke"
  display_name = "GKE Node Service Account"
  project      = var.project_id
  description  = "Service account for GKE cluster nodes"
}

# Service Account for Jenkins
resource "google_service_account" "jenkins_sa" {
  account_id   = "${var.service_account_name}-jenkins"
  display_name = "Jenkins Service Account"
  project      = var.project_id
  description  = "Service account for Jenkins CI/CD operations"
}

# IAM roles for GKE node service account
resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# IAM roles for Jenkins service account
resource "google_project_iam_member" "jenkins_roles" {
  for_each = toset([
    "roles/container.developer",
    "roles/container.clusterViewer",
    "roles/storage.admin",
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/compute.instanceAdmin.v1",
    "roles/iam.serviceAccountUser"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

# Service account key for Jenkins (to be stored on Jenkins VM)
resource "google_service_account_key" "jenkins_key" {
  service_account_id = google_service_account.jenkins_sa.name
  public_key_type    = "TYPE_X509_PEM_FILE"
  private_key_type   = "TYPE_GOOGLE_CREDENTIALS_FILE"
}

# Allow Jenkins SA to act as GKE node SA
resource "google_service_account_iam_member" "jenkins_impersonate_gke" {
  service_account_id = google_service_account.gke_node_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

# Workload Identity binding (optional, for GKE workloads)
resource "google_service_account_iam_member" "workload_identity_binding" {
  count = var.enable_workload_identity ? 1 : 0

  service_account_id = google_service_account.jenkins_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.workload_identity_namespace}/${var.workload_identity_sa_name}]"
}
