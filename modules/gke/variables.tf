# GKE Module - Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "zone" {
  description = "GCP Zone for the cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster_version" {
  description = "GKE cluster version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "vpc_self_link" {
  description = "Self link of the VPC network"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet"
  type        = string
}

variable "pods_cidr_name" {
  description = "Name of the secondary range for pods"
  type        = string
}

variable "services_cidr_name" {
  description = "Name of the secondary range for services"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the primary node pool"
  type        = string
  default     = "default-pool"
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB for nodes"
  type        = number
  default     = 50
}

variable "disk_type" {
  description = "Disk type for nodes (pd-standard, pd-ssd, pd-balanced)"
  type        = string
  default     = "pd-standard"
}

variable "preemptible" {
  description = "Use preemptible VMs for nodes"
  type        = bool
  default     = true
}

variable "use_spot_vms" {
  description = "Use Spot VMs for nodes (newer than preemptible)"
  type        = bool
  default     = false
}

variable "node_service_account" {
  description = "Service account email for nodes"
  type        = string
}

variable "enable_private_nodes" {
  description = "Enable private nodes (no external IPs)"
  type        = bool
  default     = true
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the master's private endpoint"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of authorized networks for master access"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  ]
}

variable "enable_network_policy" {
  description = "Enable network policy addon"
  type        = bool
  default     = false
}

variable "release_channel" {
  description = "Release channel for GKE (UNSPECIFIED, RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "enable_managed_prometheus" {
  description = "Enable managed Prometheus"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = false
}

variable "create_spot_node_pool" {
  description = "Create an additional Spot node pool for batch workloads"
  type        = bool
  default     = false
}

variable "spot_max_node_count" {
  description = "Maximum nodes for spot node pool"
  type        = number
  default     = 3
}

variable "spot_machine_type" {
  description = "Machine type for spot nodes"
  type        = string
  default     = "e2-medium"
}
