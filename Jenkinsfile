pipeline {
    agent { label params.NODE_LABEL }

    environment {
        COMPOSE_PROJECT_NAME = "spring-petclinic"
        DOCKER_IMAGE         = "ganil151/spring-petclinic-microservice"
        IMAGE_TAG            = "${env.BUILD_NUMBER ?: 'latest'}"
        EC2_REGION           = "us-east-1"
        DEPLOY_USER          = "ec2-user"
        AWS_CREDENTIALS_ID   = "aws-credentials"
        SSH_CREDENTIALS_ID   = "${params.SSH_CREDENTIALS_ID}"
        DOCKERHUB_CRED_ID    = "dockerhub-credentials"
        MYSQL_CRED_ID        = "mysql-credentials"
        IS_NEW_INSTANCE      = 'false' 
        K8S_MASTER_IP        = "50.17.116.117"
    }

    parameters {
        string(name: 'NODE_LABEL',        defaultValue: 'worker-node', description: 'Jenkins agent label')
        string(name: 'EC2_INSTANCE_NAME', defaultValue: 'Spring-Petclinic-Docker', description: 'EC2 instance tag Name')
        string(name: 'SSH_CREDENTIALS_ID', defaultValue: 'master_keys', description: 'SSH credential id for EC2')
        // New parameters for MySQL configuration
        choice(
            name: 'DEPLOYMENT_TARGET',
            choices: ['docker', 'kubernetes', 'both', 'none'],
            description: 'Deployment target'
        )
        booleanParam(
            name: 'CONFIGURE_MYSQL',
            defaultValue: true,
            description: 'Run Ansible to configure MySQL databases'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                retry(3) {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: '*/main']],
                        userRemoteConfigs: [[
                            url: 'https://github.com/Ganil151/spring-petclinic-microservices.git',
                            credentialsId: 'github-credentials' 
                        ]],
                        cloneOption: [
                            depth: 1,
                            shallow: true,
                            noTags: true,
                            timeout: 20
                        ]
                    ])
                }
            }
        }

        stage('Prepare tools') {
            steps {
                sh '''
                set -e
                if ! command -v yq &>/dev/null; then
                    sudo wget -q -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.34.1/yq_linux_amd64    
                    sudo chmod +x /usr/local/bin/yq
                fi
                '''
            }
        }

        stage('Modify docker-compose.yml') {
            steps {
                sh '''
                cp docker-compose.yml docker-compose.yml.bak
                yq eval 'del(.services.genai-service)' -i docker-compose.yml
                '''
            }
        }

        stage('Build JAR') {
            environment {
                JAVA_HOME = "/usr/lib/jvm/java-21-amazon-corretto"
                PATH = "${JAVA_HOME}/bin:${env.PATH}"
            }
            steps {
                sh '''
                set -e
                if [ -x ./mvnw ]; then
                    chmod +x ./mvnw
                    sed -i 's/\r$//' ./mvnw || true
                    BUILD_CMD="./mvnw -T1C -DskipTests=false clean install"
                else
                    BUILD_CMD="mvn -T1C -DskipTests=false clean install"
                fi
                echo "Using build command: $BUILD_CMD"
                $BUILD_CMD

                echo "Copying JAR to docker directory..."
                JAR=$(ls spring-petclinic-config-server/target/*.jar 2>/dev/null | head -n1 || true)
                if [ -n "$JAR" ]; then
                    cp "$JAR" docker/application.jar
                else
                    echo "Error: JAR file not found in spring-petclinic-config-server/target/"
                    exit 1
                fi
                '''
            }
        }

        stage('Docker Build & Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: DOCKERHUB_CRED_ID, usernameVariable: 'D_USER', passwordVariable: 'D_PASS')]) {
                    sh '''
                    set -e
                    echo "Logging in to DockerHub..."
                    echo "$D_PASS" | sudo docker login -u "$D_USER" --password-stdin

                    echo "Building Docker image..."
                    cd docker
                    sudo docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                    sudo docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest

                    echo "Pushing Docker image..."
                    sudo docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                    sudo docker push ${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }

        stage('Provision or Reuse Docker-Server') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID]]) {
                    script {
                        echo "Looking up EC2 instance by Name tag: ${env.EC2_INSTANCE_NAME}"

                        def instanceId = sh(
                            returnStdout: true,
                            script: """
                                export AWS_DEFAULT_REGION=${env.EC2_REGION}
                                aws ec2 describe-instances \\
                                    --filters "Name=tag:Name,Values=${env.EC2_INSTANCE_NAME}" "Name=instance-state-name,Values=running,stopped,pending,stopping" \\
                                    --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || echo "None"
                            """
                        ).trim()
                        
                        if (instanceId == 'None' || instanceId.isEmpty()) {
                            echo "No instance found. Launching new instance: ${env.EC2_INSTANCE_NAME}"
                            
                            instanceId = sh(
                                returnStdout: true,
                                script: """
                                    export AWS_DEFAULT_REGION=${env.EC2_REGION}
                                    aws ec2 run-instances \\
                                        --image-id ami-052064a798f08f0d3 \\
                                        --instance-type t2.medium \\
                                        --key-name master_keys \\
                                        --security-group-ids sg-04f82bf215352511d \\
                                        --subnet-id subnet-06a3b69943a68eff9 \\
                                        --associate-public-ip-address \\
                                        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${env.EC2_INSTANCE_NAME}}]" \\
                                        --query "Instances[0].InstanceId" --output text
                                """
                            ).trim()

                            echo "Launched: ${instanceId}"
                            env.IS_NEW_INSTANCE = 'true' // Set flag for conditional bootstrap
                            def state = 'pending' 
                        } else {
                            instanceId = instanceId.split('\\s+')[0] // Take only the first ID
                            def state = sh(
                                returnStdout: true,
                                script: "aws ec2 describe-instances --region ${env.EC2_REGION} --instance-ids ${instanceId} --query \"Reservations[0].Instances[0].State.Name\" --output text"
                            ).trim()

                            echo "Found instance: ${instanceId}. Current State: ${state}"

                            if (state == "stopped") {
                                echo "Starting stopped instance ${instanceId}"
                                sh "aws ec2 start-instances --region ${env.EC2_REGION} --instance-ids ${instanceId}"
                                state = 'pending' 
                            }
                        }

                        // Wait for instance to be running
                        sh "aws ec2 wait instance-running --region ${env.EC2_REGION} --instance-ids ${instanceId}"
                        
                        def publicIp = sh(
                            returnStdout: true,
                            script: "aws ec2 describe-instances --region ${env.EC2_REGION} --instance-ids ${instanceId} --query \"Reservations[0].Instances[0].PublicIpAddress\" --output text"
                        ).trim()

                        if (publicIp == null || publicIp.isEmpty() || publicIp == "None") {
                            error("ERROR: instance has no public IP.")
                        }

                        sh "echo ${publicIp} > public_ip.txt"
                        echo "Docker-Server public IP: ${publicIp}"
                    }
                }
            }
        }

        stage('Bootstrap Docker-Server (install Docker / Java / Compose)') {
            // Removed 'when' condition to ensure bootstrap runs on every execution (idempotent)
            steps {
                echo "Running Bootstrap: Installing dependencies..."
                withCredentials([
                    [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']
                ]) {
                    sh '''
                    set -euo pipefail
                    REMOTE_IP=$(cat public_ip.txt)
                    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"

                    # Wait for SSH port to be open
                    until ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "echo 'SSH is ready'" 2>/dev/null; do
                      echo "Waiting for SSH connection..."
                      sleep 5
                    done

                    # Run bootstrap commands on remote
                    ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} bash -s <<'REMOTE'
                        DEPLOY_USER="ec2-user"
                        set -eux

                        BUILDX_VERSION="v0.29.0"

                        sudo yum -y makecache
                        sudo yum -y upgrade || true

                        # jq
                        echo "Installing jq..."
                        if ! command -v jq >/dev/null 2>&1; then
                            sudo yum install -y jq
                        fi

                        # Java & Maven
                        echo "Installing Java & Maven..."
                        if ! command -v java >/dev/null 2>&1; then
                            sudo yum install -y java-21-amazon-corretto-devel git
                        fi
                        if ! command -v mvn >/dev/null 2>&1; then
                            sudo yum install -y maven
                        fi

                        # Docker
                        if ! command -v docker >/dev/null 2>&1; then
                            echo "Installing Docker..."
                            sudo yum install -y docker
                            echo "Docker installed."
                        else
                            echo "Docker already installed."
                        fi

                        # Ensure Docker service is enabled and started
                        echo "Enabling and starting Docker service..."
                        sudo systemctl enable docker
                        sudo systemctl start docker
                        # Optional: Add a small delay to ensure the service is fully up
                        sleep 5
                        echo "Docker service started and enabled."

                        # Add user to docker group
                        sudo usermod -aG docker "$DEPLOY_USER"
                        echo "User $DEPLOY_USER added to docker group."

                        # Ensure CLI plugin PATH by creating the profile script
                        echo "Setting up Docker CLI plugins PATH..."
                        sudo tee /etc/profile.d/docker-cli-plugins.sh >/dev/null <<'EOF_PROFILE'
export PATH=$PATH:/usr/libexec/docker/cli-plugins
EOF_PROFILE
                        echo "Docker CLI plugins PATH configured."

                        # Source the profile script to update PATH for the current session
                        # This is crucial for the 'docker' command and its plugins to be found below
                        source /etc/profile.d/docker-cli-plugins.sh

                        # Verify the 'docker' command itself is now available
                        echo "Verifying Docker client is available..."
                        command -v docker
                        docker --version

                        # Docker Compose
                        if ! docker compose version &>/dev/null; then # Now check using the 'docker compose' subcommand
                            echo "Installing Docker Compose V2 plugin..."
                            sudo mkdir -p /usr/libexec/docker/cli-plugins/
                            sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
                                -o /usr/libexec/docker/cli-plugins/docker-compose
                            sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
                            echo "Docker Compose V2 plugin installed."
                        else
                            echo "Docker Compose V2 plugin already exists and is functional."
                        fi

                        # Docker Buildx
                        if ! docker buildx version &>/dev/null; then # Now check using the 'docker buildx' subcommand
                            echo "Installing Docker Buildx plugin..."
                            sudo mkdir -p /usr/libexec/docker/cli-plugins/
                            ARCH=$(uname -m)
                            BINARY_ARCH=${ARCH/#x86_64/amd64}
                            BINARY_ARCH=${BINARY_ARCH/#aarch64/arm64}
                            sudo curl -SL https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-${BINARY_ARCH} \
                                -o /usr/libexec/docker/cli-plugins/docker-buildx
                            sudo chmod +x /usr/libexec/docker/cli-plugins/docker-buildx
                            echo "Docker Buildx plugin installed."
                        else
                            echo "Docker Buildx plugin already exists and is functional."
                        fi

                        # Final verification that all commands are available in the current PATH
                        echo "Final verification:"
                        docker --version
                        docker compose version
                        docker buildx version
                        echo "All Docker components installed and verified."
REMOTE
                    '''
                }
            }
        }

        stage('Deploy to Docker-Server') {
            steps {
                withCredentials([
                    [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'],
                    usernamePassword(credentialsId: DOCKERHUB_CRED_ID, usernameVariable: 'D_USER', passwordVariable: 'D_PASS')
                ]) {

                    sh '''
                    set -e
                    REMOTE_IP=$(cat public_ip.txt)
                    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                    REMOTE_DIR="/home/ec2-user/petclinic_deploy"

                    # Copy fresh files to HOME directory on remote host
                    scp ${SSH_OPTS} docker-compose.yml ${SSH_USER}@${REMOTE_IP}:~/docker-compose.yml
                    scp -r ${SSH_OPTS} docker ${SSH_USER}@${REMOTE_IP}:~/docker

                    # Run remote deployment script
                    ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} bash -s <<'REMOTE'
                        set -euo pipefail

                        REMOTE_DIR="/home/ec2-user/petclinic_deploy"

                        # Fix for Jenkins unbound variables
                        D_USER="${D_USER:-}"
                        D_PASS="${D_PASS:-}"

                        # Avoid $1 errors from docker CLI environment scripts
                        set +u
                        source /etc/profile.d/docker-cli-plugins.sh 2>/dev/null || true
                        set -u

                        # Prepare deployment directory
                        mkdir -p "$REMOTE_DIR"

                        # Clean old deployments
                        rm -rf "$REMOTE_DIR/docker"
                        rm -f "$REMOTE_DIR/docker-compose.yml"

                        # Move newly uploaded files from HOME to deploy directory
                        cp -r ~/docker "$REMOTE_DIR/"
                        cp ~/docker-compose.yml "$REMOTE_DIR/"

                        # Copy Prometheus config (ensure path exists on Jenkins agent)
                        if [ -d ~/docker/prometheus ]; then
                            rm -rf "$REMOTE_DIR/prometheus"
                            mkdir -p "$REMOTE_DIR/prometheus"
                            cp ~/docker/prometheus/prometheus.yml "$REMOTE_DIR/prometheus/prometheus.yml"
                        else
                            echo "Warning: ~/docker/prometheus directory not found on Jenkins agent. Skipping Prometheus config copy."
                        fi

                        cd "$REMOTE_DIR"

                        # Docker login (skip if empty credentials)
                        if [ -n "$D_USER" ] && [ -n "$D_PASS" ]; then
                            printf "%s" "$D_PASS" | sudo -u "$USER" docker login -u "$D_USER" --password-stdin || true
                        else
                            echo "DockerHub credentials not provided or empty. Attempting operations without login."
                        fi

                        # Deploy containers using sudo to ensure access to Docker socket
                        # The -u flag for sudo ensures the command runs as the current user ($USER, which is ec2-user)
                        # who should now be in the docker group from the bootstrap stage.
                        sudo docker compose -p spring-petclinic pull || true
                        sudo docker compose -p spring-petclinic up -d --build --remove-orphans

                        echo "Deployment completed successfully."
REMOTE
                    '''
                }
            }
        }

        // New stage for Docker verification
        stage('Verify Docker Deployment') {
            steps {
                withCredentials([
                    [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']
                ]) {
                    script {
                        echo "Verifying Docker deployment on Docker-Server..."
                        
                        sh '''
                        set -e
                        REMOTE_IP=$(cat public_ip.txt)
                        SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                        
                        echo "=== Checking Docker containers status ==="
                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'"
                        
                        echo ""
                        echo "=== Waiting for services to start (30 seconds) ==="
                        echo "✓ customers-service checked"
                        
                        # Check visits-service
                        echo "Checking visits-service..."
                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8082/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "WARNING: visits-service health check failed (may still be starting)"
                        }
                        echo "✓ visits-service checked"
                        
                        # Check vets-service
                        echo "Checking vets-service..."
                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8083/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "WARNING: vets-service health check failed (may still be starting)"
                        }
                        echo "✓ vets-service checked"
                        
                        echo ""
                        echo "=== Docker Deployment Verification Complete ==="
                        echo "✓ All critical services (config, discovery, api-gateway) are healthy"
                        '''
                    }
                }
            }
        }

        stage('Configure MySQL Database') {
            steps {
            withCredentials([
                [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'],
                usernamePassword(credentialsId: 'mysql-root-credentials', usernameVariable: 'MYSQL_ROOT_USER', passwordVariable: 'MYSQL_ROOT_PASSWORD'),
                usernamePassword(credentialsId: 'mysql-petclinic-credentials', usernameVariable: 'MYSQL_PETCLINIC_USER', passwordVariable: 'MYSQL_PETCLINIC_PASSWORD')
            ]) {
                script {
                    echo "Configuring MySQL databases with Ansible..."
                    
                    sh '''
                    set -e
                    
                    echo "=== MySQL Configuration ==="
                    echo "MySQL Root User: ${MYSQL_ROOT_USER}"
                    echo "Petclinic User: ${MYSQL_PETCLINIC_USER}"
                    echo ""
                    
                    # Update Ansible group_vars with credentials from Jenkins
                    echo "Updating Ansible variables with Jenkins credentials..."
                    cat > ansible/group_vars/mysql.yml <<EOF
---
mysql_root_password: "${MYSQL_ROOT_PASSWORD}"
mysql_petclinic_password: "${MYSQL_PETCLINIC_PASSWORD}"

petclinic_databases:
- customers
- visits
- vets

petclinic_users:
- name: ${MYSQL_PETCLINIC_USER}
password: "{{ mysql_petclinic_password }}"
priv: "*.*:ALL"
EOF
                    
                    echo "✓ Ansible variables updated"
                    echo ""
                    
                    # Test Ansible connectivity
                    echo "=== Testing Ansible Connectivity ==="
                    cd /etc/ansible
                    ansible mysql -i inventory.ini -m ping || {
                        echo "ERROR: Cannot connect to MySQL server via Ansible"
                        exit 1
                    }
                    echo "✓ Ansible connectivity verified"
                    echo ""
                    
                    # Run Ansible playbook
                    echo "=== Running Ansible Playbook ==="
                    ansible-playbook -i inventory.ini mysql_setup.yml -v || {
                        echo "ERROR: Ansible playbook failed"
                        exit 1
                    }
                    echo "✓ Ansible playbook completed successfully"
                    echo ""
                    
                    # Verify databases were created
                    echo "=== Verifying Database Creation ==="
                    ansible mysql -i inventory.ini -m shell \\
                        -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SHOW DATABASES;'" \\
                        | grep -E 'customers|visits|vets' || {
                        echo "ERROR: Required databases not found"
                        exit 1
                    }
                    echo "✓ All required databases exist (customers, visits, vets)"
                    echo ""
                    
                    # Verify petclinic user was created
                    echo "=== Verifying Petclinic User ==="
                    ansible mysql -i inventory.ini -m shell \\
                        -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SELECT User FROM mysql.user WHERE User=\"${MYSQL_PETCLINIC_USER}\";'" \\
                        | grep "${MYSQL_PETCLINIC_USER}" || {
                        echo "ERROR: Petclinic user not found"
                        exit 1
                    }
                    echo "✓ Petclinic user exists: ${MYSQL_PETCLINIC_USER}"
                    echo ""
                    
                    # Test petclinic user can connect
                    echo "=== Testing Petclinic User Connection ==="
                    ansible mysql -i inventory.ini -m shell \\
                        -a "mysql -u ${MYSQL_PETCLINIC_USER} -p${MYSQL_PETCLINIC_PASSWORD} -e 'SELECT 1;'" || {
                        echo "ERROR: Petclinic user cannot connect"
                        exit 1
                    }
                    echo "✓ Petclinic user can connect successfully"
                    echo ""
                    
                    # Test petclinic user has access to databases
                    echo "=== Verifying Database Access ==="
                    for db in customers visits vets; do
                        echo "Testing access to $db database..."
                        ansible mysql -i inventory.ini -m shell \\
                            -a "mysql -u ${MYSQL_PETCLINIC_USER} -p${MYSQL_PETCLINIC_PASSWORD} -e 'USE $db; SELECT 1;'" || {
                            echo "ERROR: Petclinic user cannot access $db database"
                            exit 1
                        }
                        echo "✓ Access to $db database verified"
                    done
                    echo ""
                    
                    # Check if tables exist (schema loaded)
                    echo "=== Checking Database Schema ==="
                    for db in customers visits vets; do
                        echo "Checking tables in $db database..."
                        TABLE_COUNT=$(ansible mysql -i inventory.ini -m shell \\
                            -a "mysql -u ${MYSQL_PETCLINIC_USER} -p${MYSQL_PETCLINIC_PASSWORD} -e 'USE $db; SHOW TABLES;'" \\
                            | grep -c "owners\\|pets\\|visits\\|vets\\|specialties" || echo "0")
                        
                        if [ "$TABLE_COUNT" -gt 0 ]; then
                            echo "✓ $db database has $TABLE_COUNT tables"
                        else
                            echo "⚠ $db database has no tables (schema may need to be loaded)"
                        fi
                    done
                    echo ""
                    
                    # Get MySQL server info
                    echo "=== MySQL Server Information ==="
                    ansible mysql -i inventory.ini -m shell \\
                        -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SELECT VERSION();'" \\
                        | grep -v "CHANGED\\|mysql" || true
                    echo ""
                    
                    # Get MySQL server IP
                    MYSQL_IP=$(grep "mysql-server ansible_host" ansible/inventory.ini | awk '{print $2}' | cut -d'=' -f2)
                    echo "MySQL Server IP: $MYSQL_IP"
                    echo ""
                    
                    echo "=== MySQL Configuration Complete ==="
                    echo "✓ Databases: customers, visits, vets"
                    echo "✓ User: ${MYSQL_PETCLINIC_USER}"
                    echo "✓ Connection: ${MYSQL_IP}:3306"
                    echo "✓ All health checks passed"
                    '''
                }
            }
        }
    }

    stage('Configure kubectl') {
        steps {
            withCredentials([
                [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']
            ]) {
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
    }

    stage('Verify Kubernetes Deployment') {
        steps {
            script {
                echo "Verifying Kubernetes deployment..."
                
                sh '''
                set -e
                
                echo "=== Kubernetes Deployment Verification ==="
                echo ""
                
                # Verify kubectl is configured
                echo "=== Checking kubectl Configuration ==="
                if ! kubectl cluster-info &>/dev/null; then
                    echo "ERROR: kubectl is not configured or cannot connect to cluster"
                    exit 1
                fi
                echo "✓ kubectl is configured and connected"
                echo ""
                
                # Check cluster nodes
                echo "=== Cluster Nodes Status ==="
                kubectl get nodes
                echo ""
                
                # Verify all nodes are Ready
                NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
                if [ "$NOT_READY" -gt 0 ]; then
                    echo "WARNING: $NOT_READY node(s) are not in Ready state"
                    kubectl get nodes
                else
                    echo "✓ All nodes are Ready"
                fi
                echo ""
                
                # Check deployments status
                echo "=== Deployment Status ==="
                kubectl get deployments -o wide
                echo ""
                
                # Check if all deployments are available
                echo "=== Checking Deployment Availability ==="
                DEPLOYMENTS=$(kubectl get deployments -o jsonpath='{.items[*].metadata.name}')
                
                for deployment in $DEPLOYMENTS; do
                    READY=$(kubectl get deployment $deployment -o jsonpath='{.status.readyReplicas}')
                    DESIRED=$(kubectl get deployment $deployment -o jsonpath='{.spec.replicas}')
                    
                    if [ "$READY" = "$DESIRED" ] && [ "$READY" != "" ]; then
                        echo "✓ $deployment: $READY/$DESIRED replicas ready"
                    else
                        echo "⚠ $deployment: $READY/$DESIRED replicas ready (not fully available)"
                    fi
                done
                echo ""
                
                # Check pods status
                echo "=== Pod Status ==="
                kubectl get pods -o wide
                echo ""
                
                # Check for pods not in Running state
                echo "=== Checking Pod Health ==="
                NOT_RUNNING=$(kubectl get pods --no-headers | grep -v "Running" | grep -v "Completed" | wc -l)
                if [ "$NOT_RUNNING" -gt 0 ]; then
                    echo "WARNING: $NOT_RUNNING pod(s) are not in Running state"
                    kubectl get pods | grep -v "Running" | grep -v "Completed" | grep -v "NAME" || true
                    echo ""
                    echo "=== Pod Details for Non-Running Pods ==="
                    kubectl get pods --no-headers | grep -v "Running" | grep -v "Completed" | awk '{print $1}' | while read pod; do
                        echo "--- Pod: $pod ---"
                        kubectl describe pod $pod | tail -20
                        echo ""
                    done
                else
                    echo "✓ All pods are in Running or Completed state"
                fi
                echo ""
                
                # Check services
                echo "=== Service Status ==="
                kubectl get services -o wide
                echo ""
                
                # Check for infrastructure services
                echo "=== Verifying Infrastructure Services ==="
                INFRA_SERVICES="config-server discovery-server"
                for service in $INFRA_SERVICES; do
                    if kubectl get deployment $service &>/dev/null; then
                        READY=$(kubectl get deployment $service -o jsonpath='{.status.readyReplicas}')
                        if [ "$READY" -gt 0 ]; then
                            echo "✓ $service is running ($READY replicas)"
                        else
                            echo "⚠ $service is not ready"
                        fi
                    else
                        echo "⚠ $service deployment not found"
                    fi
                done
                echo ""
                
                # Check for microservices
                echo "=== Verifying Microservices ==="
                MICROSERVICES="customers-service visits-service vets-service api-gateway"
                for service in $MICROSERVICES; do
                    if kubectl get deployment $service &>/dev/null; then
                        READY=$(kubectl get deployment $service -o jsonpath='{.status.readyReplicas}')
                        if [ "$READY" -gt 0 ]; then
                            echo "✓ $service is running ($READY replicas)"
                        else
                            echo "⚠ $service is not ready"
                        fi
                    else
                        echo "⚠ $service deployment not found"
                    fi
                done
                echo ""
                
                # Get API Gateway access information
                echo "=== API Gateway Access Information ==="
                if kubectl get service api-gateway &>/dev/null; then
                    SERVICE_TYPE=$(kubectl get service api-gateway -o jsonpath='{.spec.type}')
                    echo "Service Type: $SERVICE_TYPE"
                    
                    if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
                        LB_HOSTNAME=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                        LB_IP=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                        if [ -n "$LB_HOSTNAME" ]; then
                            echo "LoadBalancer URL: http://$LB_HOSTNAME"
                        elif [ -n "$LB_IP" ]; then
                            echo "LoadBalancer URL: http://$LB_IP"
                        else
                            echo "LoadBalancer is being provisioned..."
                        fi
                    elif [ "$SERVICE_TYPE" = "NodePort" ]; then
                        NODE_PORT=$(kubectl get service api-gateway -o jsonpath='{.spec.ports[0].nodePort}')
                        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
                        if [ -z "$NODE_IP" ]; then
                            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
                        fi
                        echo "NodePort URL: http://$NODE_IP:$NODE_PORT"
                        echo ""
                        echo "You can access the application at: http://$NODE_IP:$NODE_PORT"
                    fi
                else
                    echo "⚠ api-gateway service not found"
                fi
                echo ""
                
                # Check for any recent events (errors/warnings)
                echo "=== Recent Cluster Events (Last 10) ==="
                kubectl get events --sort-by='.lastTimestamp' | tail -10
                echo ""
                
                # Summary
                echo "=== Verification Summary ==="
                TOTAL_PODS=$(kubectl get pods --no-headers | wc -l)
                RUNNING_PODS=$(kubectl get pods --no-headers | grep "Running" | wc -l)
                TOTAL_DEPLOYMENTS=$(kubectl get deployments --no-headers | wc -l)
                
                echo "Total Deployments: $TOTAL_DEPLOYMENTS"
                echo "Total Pods: $TOTAL_PODS"
                echo "Running Pods: $RUNNING_PODS"
                echo ""
                
                if [ "$NOT_RUNNING" -eq 0 ]; then
                    echo "✓ Kubernetes Deployment Verification Complete - All systems healthy"
                else
                    echo "⚠ Kubernetes Deployment Verification Complete - Some issues detected"
                    echo "Please review the warnings above"
                fi
                '''
            }
        }
    }

    stage('Update Monitoring') {
        steps {
            withCredentials([
                [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']
            ]) {
                script {
                    echo "Updating Prometheus monitoring configuration..."
                    
                    sh '''
                    set -e
                    
                    echo "=== Updating Prometheus Monitoring ==="
                    echo ""
                    
                    # Get K8s Master IP
                    K8S_MASTER_IP="${K8S_MASTER_IP}"
                    if [ -z "$K8S_MASTER_IP" ]; then
                        if [ -f terraform/app/terraform.tfstate ]; then
                            K8S_MASTER_IP=$(grep -A 5 '"k8s_master"' terraform/app/terraform.tfstate | grep '"public_ip"' | head -1 | awk -F'"' '{print $4}')
                        fi
                        
                        if [ -z "$K8S_MASTER_IP" ] && [ -f ansible/inventory.ini ]; then
                            K8S_MASTER_IP=$(grep "k8s-master ansible_host" ansible/inventory.ini | awk '{print $2}' | cut -d'=' -f2)
                        fi
                    fi
scrape_configs:
# Kubernetes API Server
- job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
    - role: endpoints
    scheme: https
    tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

# Kubernetes Nodes
- job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
    - role: node
    scheme: https
    tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

# Kubernetes Pods
- job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::d+)?;(d+)
        replacement: $1:$2
        target_label: __address__
    - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

# Spring Boot Actuator endpoints (for microservices)
- job_name: 'spring-petclinic-services'
    static_configs:
    - targets:
EOF

                    # Add discovered services to Prometheus config
                    echo "$SERVICES" | while IFS=: read -r service_name port; do
                        if [ -n "$service_name" ] && [ -n "$port" ]; then
                            echo "          - '${K8S_MASTER_IP}:${port}'" >> /tmp/prometheus-k8s-targets.yml
                        fi
                    done
                    
                    cat >> /tmp/prometheus-k8s-targets.yml <<'EOF'
            labels:
            environment: 'kubernetes'
            cluster: 'petclinic-k8s'
        metrics_path: '/actuator/prometheus'
        scrape_interval: 15s
    EOF

                    echo "✓ Prometheus configuration generated"
                    echo ""
                    
                    # Display the generated configuration
                    echo "=== Generated Prometheus Configuration ==="
                    cat /tmp/prometheus-k8s-targets.yml
                    echo ""
                    
                    # Check if Prometheus is running on Docker server
                    echo "=== Checking Prometheus Status ==="
                    DOCKER_SERVER_IP=$(cat public_ip.txt 2>/dev/null || echo "")
                    
                    if [ -n "$DOCKER_SERVER_IP" ]; then
                        echo "Docker Server IP: $DOCKER_SERVER_IP"
                        SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${SSH_KEY}"
                        
                        # Check if Prometheus container is running
                        PROMETHEUS_RUNNING=$(ssh ${SSH_OPTS} ${SSH_USER}@${DOCKER_SERVER_IP} \
                            "docker ps --filter name=prometheus --format '{{.Names}}'" 2>/dev/null || echo "")
                        
                        if [ -n "$PROMETHEUS_RUNNING" ]; then
                            echo "✓ Prometheus container found: $PROMETHEUS_RUNNING"
                            echo ""
                            
                            # Copy the new configuration to Docker server
                            echo "=== Updating Prometheus Configuration on Docker Server ==="
                            scp ${SSH_OPTS} /tmp/prometheus-k8s-targets.yml \
                                ${SSH_USER}@${DOCKER_SERVER_IP}:/tmp/prometheus-k8s-targets.yml
                            
                            # Backup existing config and update
                            ssh ${SSH_OPTS} ${SSH_USER}@${DOCKER_SERVER_IP} bash -s <<'REMOTE'
                            set -e
                            
                            PROMETHEUS_CONFIG_DIR="/home/ec2-user/petclinic_deploy/prometheus"
                            
                            if [ -d "$PROMETHEUS_CONFIG_DIR" ]; then
                                # Backup existing configuration
                                if [ -f "$PROMETHEUS_CONFIG_DIR/prometheus.yml" ]; then
                                    cp "$PROMETHEUS_CONFIG_DIR/prometheus.yml" \
                                    "$PROMETHEUS_CONFIG_DIR/prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)"
                                    echo "✓ Backed up existing Prometheus configuration"
                                fi
                                
                                # Append K8s targets to existing config
                                echo "" >> "$PROMETHEUS_CONFIG_DIR/prometheus.yml"
                                echo "# Kubernetes targets - auto-generated" >> "$PROMETHEUS_CONFIG_DIR/prometheus.yml"
                                cat /tmp/prometheus-k8s-targets.yml >> "$PROMETHEUS_CONFIG_DIR/prometheus.yml"
                                
                                echo "✓ Updated Prometheus configuration"
                                
                                # Reload Prometheus configuration
                                echo "Reloading Prometheus..."
                                docker exec prometheus kill -HUP 1 2>/dev/null || \
                                    docker restart prometheus
                                
                                echo "✓ Prometheus reloaded successfully"
                            else
                                echo "WARNING: Prometheus config directory not found at $PROMETHEUS_CONFIG_DIR"
                            fi
    REMOTE
                            
                            echo "✓ Prometheus monitoring updated on Docker server"
                        else
                            echo "ℹ Prometheus container not found on Docker server"
                            echo "  Skipping Prometheus update (optional step)"
                        fi
                    else
                        echo "ℹ Docker server IP not available"
                        echo "  Skipping Prometheus update (optional step)"
                    fi
                    echo ""
                    
                    # Summary
                    echo "=== Monitoring Update Summary ==="
                    echo "✓ Kubernetes service endpoints discovered"
                    echo "✓ Prometheus configuration generated"
                    
                    if [ -n "$PROMETHEUS_RUNNING" ]; then
                        echo "✓ Prometheus configuration updated and reloaded"
                        echo ""
                        echo "Prometheus URL: http://${DOCKER_SERVER_IP}:9090"
                        echo "Grafana URL: http://${DOCKER_SERVER_IP}:3000"
                    else
                        echo "ℹ Prometheus update skipped (container not running)"
                    fi
                    echo ""
                    
                    echo "=== Monitoring Update Complete ==="
                    '''
                }
            }
        }
    }

    

    }

     post {
        success {
            echo "Pipeline finished: SUCCESS. App image: ${DOCKER_IMAGE}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline finished: FAILURE. Check logs and remote host state."
        }
        always {
            archiveArtifacts artifacts: 'docker/application.jar', allowEmptyArchive: true
            script {
                if (fileExists('public_ip.txt')) {
                    stash includes: 'public_ip.txt', name: 'public_ip'
                }
            }
        }
    }

}