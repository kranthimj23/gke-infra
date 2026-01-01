# GCP GKE Jenkins Infrastructure

A complete Terraform-based infrastructure-as-code solution for provisioning a cost-optimized GKE cluster and Jenkins VM on Google Cloud Platform.

## Overview

This project provides automated provisioning of:
- Standard (non-Autopilot) GKE cluster with cost optimization features
- Jenkins CI/CD server VM with pre-configured tools
- VPC networking with proper security configurations
- Service accounts with appropriate IAM permissions
- All infrastructure parameters configurable via environment variables

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GCP Project: speedy-insight-483010-m3                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    VPC: gke-jenkins-vpc                          │   │
│  │                                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────┐     │   │
│  │  │              Subnet: gke-jenkins-subnet                  │     │   │
│  │  │              CIDR: 10.0.0.0/24                           │     │   │
│  │  │                                                          │     │   │
│  │  │  ┌──────────────────┐    ┌──────────────────────────┐   │     │   │
│  │  │  │   Jenkins VM     │    │     GKE Cluster          │   │     │   │
│  │  │  │   e2-medium      │    │   autopilot-cluster-1    │   │     │   │
│  │  │  │   Port: 8080     │───▶│                          │   │     │   │
│  │  │  │                  │    │   ┌─────────────────┐    │   │     │   │
│  │  │  │  - Docker        │    │   │  Node Pool      │    │   │     │   │
│  │  │  │  - kubectl       │    │   │  e2-medium x 2  │    │   │     │   │
│  │  │  │  - gcloud        │    │   │  (preemptible)  │    │   │     │   │
│  │  │  │  - Python 3.11   │    │   └─────────────────┘    │   │     │   │
│  │  │  └──────────────────┘    └──────────────────────────┘   │     │   │
│  │  │                                                          │     │   │
│  │  │  Secondary Ranges:                                       │     │   │
│  │  │  - Pods: 10.1.0.0/16                                     │     │   │
│  │  │  - Services: 10.2.0.0/20                                 │     │   │
│  │  └─────────────────────────────────────────────────────────┘     │   │
│  │                                                                   │   │
│  │  ┌─────────────────┐    ┌─────────────────┐                      │   │
│  │  │  Cloud Router   │───▶│   Cloud NAT     │                      │   │
│  │  └─────────────────┘    └─────────────────┘                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Service Accounts:                                                      │
│  - gke-jenkins-sa-gke (GKE nodes)                                      │
│  - gke-jenkins-sa-jenkins (Jenkins operations)                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Tools

| Tool | Minimum Version | Installation |
|------|-----------------|--------------|
| Terraform | >= 1.5.0 | [Install Guide](https://developer.hashicorp.com/terraform/downloads) |
| gcloud CLI | >= 450.0.0 | [Install Guide](https://cloud.google.com/sdk/docs/install) |
| kubectl | >= 1.28.0 | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| Git | >= 2.40.0 | [Install Guide](https://git-scm.com/downloads) |
| Python | >= 3.11 | [Install Guide](https://www.python.org/downloads/) |

### GCP Requirements

1. A GCP project with billing enabled
2. Owner or Editor role on the project
3. The following APIs enabled (automatically enabled by Terraform):
   - Compute Engine API
   - Kubernetes Engine API
   - Cloud Resource Manager API
   - IAM API
   - Service Account Credentials API

### Validate Prerequisites

```bash
./scripts/validate-prerequisites.sh
```

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository (if applicable)
cd gcp-gke-jenkins-terraform

# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### 2. Authenticate with GCP

```bash
# Login to GCP
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project speedy-insight-483010-m3
```

### 3. Run Setup

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run the master setup script
./scripts/setup.sh

# Or with auto-approve (non-interactive)
./scripts/setup.sh --auto-approve
```

### 4. Verify Deployment

```bash
./scripts/verify.sh
```

## Configuration

### Environment Variables

All infrastructure parameters are configurable via environment variables. Copy `.env.example` to `.env` and customize:

```bash
# GCP Project
export GCP_PROJECT_ID="speedy-insight-483010-m3"
export GCP_REGION="us-central1"
export GCP_ZONE="us-central1-a"

# GKE Cluster
export GKE_CLUSTER_NAME="autopilot-cluster-1"
export GKE_NODE_COUNT="2"
export GKE_NODE_MACHINE_TYPE="e2-medium"
export GKE_PREEMPTIBLE_NODES="true"

# Jenkins VM
export JENKINS_VM_NAME="jenkins-server"
export JENKINS_MACHINE_TYPE="e2-medium"
export JENKINS_HTTP_PORT="8080"

# Service Account
export SERVICE_ACCOUNT_KEY_PATH="/var/lib/jenkins/keys/speedy-insight-483010-m3-e631e1327727.json"
```

### Terraform Variables

Alternatively, use `terraform.tfvars`:

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

## Cost Optimization

This infrastructure is designed with cost optimization in mind:

### Cost-Saving Features

1. **Preemptible GKE Nodes**: Up to 80% cost savings on compute
2. **e2-medium Machine Types**: Cost-effective general-purpose VMs
3. **Standard Persistent Disks**: Lower cost than SSD for non-critical workloads
4. **Autoscaling**: Scale down to 1 node during low usage
5. **Regional Resources**: Single-zone deployment reduces costs
6. **Cloud NAT**: Shared NAT gateway instead of per-VM external IPs

### Estimated Monthly Costs

| Resource | Configuration | Estimated Cost (USD) |
|----------|---------------|---------------------|
| **GKE Cluster** | | |
| - Cluster Management | Free tier | $0.00 |
| - Node Pool (2x e2-medium, preemptible) | 2 vCPU, 4GB RAM each | ~$29.20 |
| - Boot Disks (2x 50GB pd-standard) | 100GB total | ~$4.00 |
| **Jenkins VM** | | |
| - e2-medium (non-preemptible) | 2 vCPU, 4GB RAM | ~$24.27 |
| - Boot Disk (50GB pd-standard) | 50GB | ~$2.00 |
| **Networking** | | |
| - Cloud NAT | Per-VM hour + data | ~$3.00 |
| - External IP (Jenkins) | Static IP | ~$2.92 |
| - Egress Traffic | Estimated 10GB | ~$1.20 |
| **Total Estimated** | | **~$66.59/month** |

*Note: Costs are estimates based on us-central1 pricing as of 2024. Actual costs may vary.*

### Cost Reduction Options

To further reduce costs:

```bash
# Use preemptible Jenkins VM (not recommended for production)
export JENKINS_PREEMPTIBLE="true"

# Reduce node count
export GKE_NODE_COUNT="1"
export GKE_MIN_NODE_COUNT="0"

# Use smaller machine types
export GKE_NODE_MACHINE_TYPE="e2-small"
export JENKINS_MACHINE_TYPE="e2-small"
```

**Warning**: Preemptible VMs can be terminated at any time. Not recommended for production Jenkins servers.

## Project Structure

```
gcp-gke-jenkins-terraform/
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example variable values
├── .env.example            # Environment variable template
├── modules/
│   ├── networking/         # VPC, subnets, firewall rules
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/                # Service accounts and IAM
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── gke/                # GKE cluster and node pools
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── jenkins/            # Jenkins VM
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── templates/
│           └── startup.sh  # VM startup script
├── scripts/
│   ├── setup.sh            # Master setup script
│   ├── destroy.sh          # Cleanup script
│   ├── verify.sh           # Verification script
│   ├── validate-prerequisites.sh
│   └── generate-service-account-key.sh
├── docs/
│   └── PREREQUISITES.md    # Detailed prerequisites
└── keys/                   # Service account keys (gitignored)
```

## Usage

### Deploy Infrastructure

```bash
# Interactive mode
./scripts/setup.sh

# Non-interactive mode
./scripts/setup.sh --auto-approve

# Plan only (no changes)
./scripts/setup.sh --plan-only
```

### Access Jenkins

After deployment:

```bash
# Get Jenkins URL
terraform output jenkins_url

# Get initial admin password
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --command='sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

### Connect to GKE

```bash
# Get cluster credentials
gcloud container clusters get-credentials autopilot-cluster-1 \
  --zone us-central1-a \
  --project speedy-insight-483010-m3

# Verify connection
kubectl get nodes
```

### Destroy Infrastructure

```bash
# Interactive mode
./scripts/destroy.sh

# Non-interactive mode (DANGEROUS)
./scripts/destroy.sh --auto-approve

# Full cleanup including local files
./scripts/destroy.sh --auto-approve --cleanup-local --cleanup-sa-keys
```

## Integration with Existing Pipelines

This infrastructure is designed to work with existing Jenkins Groovy pipeline files without modification. The following environment variables are automatically available on the Jenkins VM:

```bash
GOOGLE_APPLICATION_CREDENTIALS=/var/lib/jenkins/keys/speedy-insight-483010-m3-e631e1327727.json
GCP_PROJECT_ID=speedy-insight-483010-m3
GKE_CLUSTER_NAME=autopilot-cluster-1
GKE_CLUSTER_ZONE=us-central1-a
```

### Pipeline Configuration

Your existing Groovy pipelines can use these environment variables:

```groovy
pipeline {
    agent any
    environment {
        PROJECT_ID = "${env.GCP_PROJECT_ID}"
        CLUSTER_NAME = "${env.GKE_CLUSTER_NAME}"
        CLUSTER_ZONE = "${env.GKE_CLUSTER_ZONE}"
    }
    stages {
        stage('Deploy to GKE') {
            steps {
                sh '''
                    gcloud container clusters get-credentials $CLUSTER_NAME \
                        --zone $CLUSTER_ZONE \
                        --project $PROJECT_ID
                    kubectl apply -f k8s/
                '''
            }
        }
    }
}
```

## Troubleshooting

### Common Issues

**1. Terraform init fails**
```bash
# Clear Terraform cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```

**2. GKE cluster creation timeout**
```bash
# Check cluster status
gcloud container clusters describe autopilot-cluster-1 \
  --zone us-central1-a \
  --format="value(status)"
```

**3. Jenkins not accessible**
```bash
# Check VM status
gcloud compute instances describe jenkins-server --zone=us-central1-a

# Check startup script logs
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --command='sudo cat /var/log/jenkins-setup.log'

# Check Jenkins service
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --command='sudo systemctl status jenkins'
```

**4. kubectl cannot connect**
```bash
# Re-authenticate
gcloud container clusters get-credentials autopilot-cluster-1 \
  --zone us-central1-a \
  --project speedy-insight-483010-m3
```

### Logs and Debugging

```bash
# View Terraform logs
export TF_LOG=DEBUG
terraform apply

# View Jenkins logs
gcloud compute ssh jenkins-server --zone=us-central1-a \
  --command='sudo journalctl -u jenkins -f'

# View GKE cluster events
kubectl get events --sort-by='.lastTimestamp'
```

## Security Considerations

1. **Service Account Keys**: Keys are stored with 600 permissions. Rotate regularly.
2. **Firewall Rules**: Jenkins is exposed to 0.0.0.0/0 by default. Restrict in production.
3. **Private Cluster**: GKE nodes have no external IPs. Access via Cloud NAT.
4. **Shielded VMs**: Both Jenkins and GKE nodes use Shielded VM features.
5. **Workload Identity**: Enabled for GKE workloads.

### Production Recommendations

```bash
# Restrict Jenkins access to specific IPs
export JENKINS_ALLOWED_IPS='["YOUR_IP/32"]'

# Disable preemptible nodes for production
export GKE_PREEMPTIBLE_NODES="false"

# Enable deletion protection
# Set in terraform.tfvars: gke_deletion_protection = true
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `terraform fmt` and `terraform validate`
5. Submit a pull request

## License

This project is provided as-is for educational and development purposes.

## Support

For issues and questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review GCP documentation
- Open an issue in the repository
