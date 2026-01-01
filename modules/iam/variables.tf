# IAM Module - Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_account_name" {
  description = "Base name for service accounts"
  type        = string
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity for GKE"
  type        = bool
  default     = false
}

variable "workload_identity_namespace" {
  description = "Kubernetes namespace for Workload Identity"
  type        = string
  default     = "default"
}

variable "workload_identity_sa_name" {
  description = "Kubernetes service account name for Workload Identity"
  type        = string
  default     = "default"
}
