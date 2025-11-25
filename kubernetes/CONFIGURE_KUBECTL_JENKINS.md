# Configure kubectl on Jenkins Worker-Server

## Problem
The Jenkins pipeline is failing at the "Deploy to Kubernetes" stage because kubectl is not configured on the Jenkins Worker-Server.

## Solution
Add a new stage to configure kubectl before deploying to Kubernetes.

## Stage to Add

Insert this stage **before** the "Deploy to Kubernetes" stage in your Jenkinsfile (around line 583):

```groovy
stage('Configure kubectl') {
    steps {
        script {
            echo "Configuring kubectl on Jenkins agent..."
            
            sh '''
            set -e
            
            echo "=== kubectl Configuration ==="
            
            # Check if kubectl is installed
            if ! command -v kubectl &>/dev/null; then
                echo "Installing kubectl..."
                
                # Add Kubernetes repository if not exists
                if [ ! -f /etc/yum.repos.d/kubernetes.repo ]; then
                    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
                fi
                
                # Install kubectl
                sudo dnf install -y kubectl --disableexcludes=kubernetes
                echo "✓ kubectl installed"
            else
                echo "✓ kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
            fi
            
            # Get K8s Master IP from Terraform or inventory
            if [ -f terraform/app/terraform.tfstate ]; then
                K8S_MASTER_IP=$(grep -A 5 '"k8s_master"' terraform/app/terraform.tfstate | grep '"public_ip"' | head -1 | awk -F'"' '{print $4}')
            fi
            
            # Fallback: try to get from Ansible inventory
            if [ -z "$K8S_MASTER_IP" ] && [ -f ansible/inventory.ini ]; then
                K8S_MASTER_IP=$(grep "k8s-master ansible_host" ansible/inventory.ini | awk '{print $2}' | cut -d'=' -f2)
            fi
            
            if [ -z "$K8S_MASTER_IP" ]; then
                echo "ERROR: Could not determine K8s Master IP"
                echo "Please set K8S_MASTER_IP environment variable or update inventory"
                exit 1
            fi
            
            echo "K8s Master IP: $K8S_MASTER_IP"
            
            # Create .kube directory
            mkdir -p ~/.kube
            
            # Copy kubeconfig from K8s master
            echo "Copying kubeconfig from master..."
            scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
                ec2-user@${K8S_MASTER_IP}:/home/ec2-user/.kube/config \
                ~/.kube/config || {
                echo "ERROR: Failed to copy kubeconfig from master"
                echo "Ensure K8s master is accessible and kubeconfig exists"
                exit 1
            }
            
            # Set proper permissions
            chmod 600 ~/.kube/config
            
            echo "✓ kubeconfig copied successfully"
            echo ""
            
            # Verify kubectl works
            echo "=== Verifying kubectl Configuration ==="
            kubectl cluster-info
            echo ""
            
            echo "=== Cluster Nodes ==="
            kubectl get nodes
            echo ""
            
            echo "✓ kubectl configured and connected to cluster"
            '''
        }
    }
}
```

## Alternative: Simpler Version (if you know the master IP)

If you want to hardcode the master IP or use a Jenkins parameter:

```groovy
stage('Configure kubectl') {
    steps {
        script {
            echo "Configuring kubectl on Jenkins agent..."
            
            sh '''
            set -e
            
            # Install kubectl if not present
            if ! command -v kubectl &>/dev/null; then
                sudo dnf install -y kubectl --disableexcludes=kubernetes
            fi
            
            # Set K8s Master IP (update this with your actual IP)
            K8S_MASTER_IP="10.0.1.100"  # CHANGE THIS
            
            # Copy kubeconfig
            mkdir -p ~/.kube
            scp -o StrictHostKeyChecking=no ec2-user@${K8S_MASTER_IP}:/home/ec2-user/.kube/config ~/.kube/config
            chmod 600 ~/.kube/config
            
            # Verify
            kubectl cluster-info
            kubectl get nodes
            '''
        }
    }
}
```

## Manual Setup (One-Time)

If you prefer to configure kubectl manually on the Jenkins Worker-Server:

```bash
# SSH to Jenkins Worker-Server
ssh ec2-user@<jenkins-worker-ip>

# Install kubectl
sudo dnf install -y kubectl --disableexcludes=kubernetes

# Copy kubeconfig from K8s Master
mkdir -p ~/.kube
scp ec2-user@<k8s-master-ip>:~/.kube/config ~/.kube/config
chmod 600 ~/.kube/config

# Verify
kubectl cluster-info
kubectl get nodes
```

After manual setup, the pipeline will work without adding the stage.

## Recommended Approach

**Option 1 (Best):** Add the "Configure kubectl" stage to the Jenkinsfile for automated setup.

**Option 2 (Quick):** Manually configure kubectl once on the Jenkins Worker-Server, then the pipeline will work.

Choose based on whether you want automated setup (Option 1) or one-time manual setup (Option 2).
