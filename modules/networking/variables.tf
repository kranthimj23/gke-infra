# Networking Module - Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_cidr_name" {
  description = "Name of the secondary range for GKE pods"
  type        = string
  default     = "gke-pods"
}

variable "pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr_name" {
  description = "Name of the secondary range for GKE services"
  type        = string
  default     = "gke-services"
}

variable "services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/20"
}

variable "jenkins_http_port" {
  description = "Jenkins HTTP port"
  type        = string
  default     = "8080"
}

variable "jenkins_jnlp_port" {
  description = "Jenkins JNLP port for agents"
  type        = string
  default     = "50000"
}

variable "jenkins_allowed_ips" {
  description = "List of IP ranges allowed to access Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
