#!/bin/bash
#
# Jenkins VM Startup Script
# This script installs and configures Jenkins with all required dependencies
#

set -e

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/jenkins-setup.log
}

log "Starting Jenkins VM setup..."

# Update system packages
log "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install basic dependencies
log "Installing basic dependencies..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    unzip \
    jq \
    git

# Install Java (required for Jenkins)
log "Installing Java 17..."
apt-get install -y openjdk-17-jdk
java -version

# Install Jenkins
log "Installing Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins

# Configure Jenkins ports
log "Configuring Jenkins ports..."
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf << EOF
[Service]
Environment="JENKINS_PORT=${jenkins_http_port}"
EOF

# Install Docker
%{ if install_docker }
log "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add jenkins user to docker group
usermod -aG docker jenkins
%{ endif }

# Install Google Cloud SDK
%{ if install_gcloud }
log "Installing Google Cloud SDK..."
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt-get update -y
apt-get install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin
%{ endif }

# Install kubectl
%{ if install_kubectl }
log "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client
%{ endif }

# Install Python
log "Installing Python ${python_version}..."
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update -y
apt-get install -y python${python_version} python${python_version}-venv python${python_version}-dev python3-pip
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${python_version} 1

# Install Helm
log "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create directories for Jenkins
log "Creating Jenkins directories..."
mkdir -p /var/lib/jenkins/keys
mkdir -p /var/lib/jenkins/workspace
chown -R jenkins:jenkins /var/lib/jenkins

# Setup service account key
log "Setting up service account key..."
%{ if service_account_key != "" }
echo '${service_account_key}' | base64 -d > ${sa_key_path}
chmod 600 ${sa_key_path}
chown jenkins:jenkins ${sa_key_path}

# Authenticate with gcloud using service account
su - jenkins -c "gcloud auth activate-service-account --key-file=${sa_key_path}"
su - jenkins -c "gcloud config set project ${project_id}"
%{ endif }

# Configure kubectl for GKE cluster
%{ if gke_cluster_name != "" }
log "Configuring kubectl for GKE cluster..."
su - jenkins -c "gcloud container clusters get-credentials ${gke_cluster_name} --zone ${gke_cluster_zone} --project ${project_id}" || true
%{ endif }

# Set environment variables for Jenkins
log "Setting environment variables..."
cat >> /etc/environment << EOF
GOOGLE_APPLICATION_CREDENTIALS=${sa_key_path}
GCP_PROJECT_ID=${project_id}
GKE_CLUSTER_NAME=${gke_cluster_name}
GKE_CLUSTER_ZONE=${gke_cluster_zone}
EOF

# Create Jenkins environment file
cat > /etc/default/jenkins << EOF
JAVA_ARGS="-Djava.awt.headless=true"
JENKINS_PORT=${jenkins_http_port}
JENKINS_ARGS="--httpPort=${jenkins_http_port}"
EOF

# Reload systemd and start Jenkins
log "Starting Jenkins service..."
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
log "Waiting for Jenkins to start..."
sleep 30

# Get initial admin password
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    log "Jenkins initial admin password:"
    cat /var/lib/jenkins/secrets/initialAdminPassword
fi

# Install Jenkins plugins via CLI (optional)
log "Jenkins setup complete!"
log "Access Jenkins at http://$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H 'Metadata-Flavor: Google'):${jenkins_http_port}"

# Final status
log "Jenkins VM setup completed successfully!"
