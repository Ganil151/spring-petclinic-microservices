pipeline {
    agent { label params.NODE_LABEL }

    parameters {
        string(name: 'NODE_LABEL', defaultValue: 'worker-node', description: 'Label of the Jenkins agent to run on')
        string(name: 'SSH_CREDENTIALS_ID', defaultValue: 'ssh-credentials', description: 'Jenkins credentials ID for SSH')
        booleanParam(name: 'CONFIGURE_MYSQL', defaultValue: false, description: 'Whether to run Ansible MySQL configuration')
        choice(name: 'DEPLOYMENT_TARGET', choices: ['docker', 'kubernetes', 'both'], description: 'Where to deploy the application')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod', 'all'], description: 'Target environment for ArgoCD')
        string(name: 'EC2_INSTANCE_NAME', defaultValue: 'petclinic-docker-server', description: 'Name tag for the Docker Server EC2 instance')
    }

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
        ANSIBLE_INVENTORY    = "ansible/inventory.ini"
        MYSQL_SCHEMA_PATH    = "ansible/files/mysql_schema.sql"
        MYSQL_ROOT_CREDENTIALS_ID = "mysql-root-credentials"
        MYSQL_PETCLINIC_CREDENTIALS_ID = "mysql-petclinic-credentials"
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
                        extensions: [[$class: 'CloneOption', depth: 1, noTags: true, shallow: true, timeout: 20]]
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
                yq eval 'del(.services.genai-service)' -i docker-compose.yml || true
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
                if [ -f ./mvnw ]; then
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
                    sudo docker push ${DOCKER_IMAGE}:${IMAGE_TAG} || true
                    sudo docker push ${DOCKER_IMAGE}:latest || true
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
                                        --security-group-ids sg-06a56ca2d53742ffd \\
                                        --subnet-id subnet-0ad91a766a9912c0f \\
                                        --associate-public-ip-address \\
                                        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${env.EC2_INSTANCE_NAME}}]" \\
                                        --query "Instances[0].InstanceId" --output text
                                """
                            ).trim()

                            echo "Launched: ${instanceId}"
                            env.IS_NEW_INSTANCE = 'true'
                        } else {
                            instanceId = instanceId.split('\\s+')[0]
                            def state = sh(
                                returnStdout: true,
                                script: "aws ec2 describe-instances --region ${env.EC2_REGION} --instance-ids ${instanceId} --query \"Reservations[0].Instances[0].State.Name\" --output text"
                            ).trim()

                            echo "Found instance: ${instanceId}. Current State: ${state}"

                            if (state == "stopped") {
                                echo "Starting stopped instance ${instanceId}"
                                sh "aws ec2 start-instances --region ${env.EC2_REGION} --instance-ids ${instanceId}"
                            }
                        }

                        sh "aws ec2 wait instance-running --region ${env.EC2_REGION} --instance-ids ${instanceId}"

                        def publicIp = sh(
                            returnStdout: true,
                            script: "aws ec2 describe-instances --region ${env.EC2_REGION} --instance-ids ${instanceId} --query \"Reservations[0].Instances[0].PublicIpAddress\" --output text"
                        ).trim()

                        if (!publicIp) {
                            error("ERROR: instance has no public IP.")
                        }

                        sh "echo ${publicIp} > public_ip.txt"
                        echo "Docker-Server public IP: ${publicIp}"
                    }
                }
            }
        }

        stage('Bootstrap Docker-Server (install Docker / Java / Compose)') {
            steps {
                echo "Running Bootstrap: Installing dependencies..."
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    sh '''
                    set -euo pipefail
                    REMOTE_IP=$(cat public_ip.txt)
                    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"

                    until ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "echo 'SSH is ready'" 2>/dev/null; do
                      echo "Waiting for SSH connection..."
                      sleep 5
                    done

                    ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} bash -s <<'REMOTE'
                        DEPLOY_USER="ec2-user"
                        set -eux

                        BUILDX_VERSION="v0.29.0"

                        sudo yum -y makecache
                        sudo yum -y upgrade || true

                        if ! command -v jq >/dev/null 2>&1; then
                            sudo yum install -y jq
                        fi

                        if ! command -v java >/dev/null 2>&1; then
                            sudo yum install -y java-21-amazon-corretto-devel git
                        fi
                        if ! command -v mvn >/dev/null 2>&1; then
                            sudo yum install -y maven
                        fi

                        if ! command -v docker >/dev/null 2>&1; then
                            sudo yum install -y docker
                        fi

                        sudo systemctl enable docker
                        sudo systemctl start docker
                        sleep 5

                        sudo usermod -aG docker "$DEPLOY_USER"

                        sudo tee /etc/profile.d/docker-cli-plugins.sh >/dev/null <<'EOF_PROFILE'
export PATH=$PATH:/usr/libexec/docker/cli-plugins
EOF_PROFILE

                        source /etc/profile.d/docker-cli-plugins.sh || true

                        docker --version || true

                        if ! docker compose version &>/dev/null; then
                            sudo mkdir -p /usr/libexec/docker/cli-plugins/
                            sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
                                -o /usr/libexec/docker/cli-plugins/docker-compose
                            sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
                        fi

                        if ! docker buildx version &>/dev/null; then
                            sudo mkdir -p /usr/libexec/docker/cli-plugins/
                            ARCH=$(uname -m)
                            BINARY_ARCH=${ARCH/#x86_64/amd64}
                            BINARY_ARCH=${BINARY_ARCH/#aarch64/arm64}
                            sudo curl -SL https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-${BINARY_ARCH} \
                                -o /usr/libexec/docker/cli-plugins/docker-buildx
                            sudo chmod +x /usr/libexec/docker/cli-plugins/docker-buildx
                        fi

                        docker --version || true
                        docker compose version || true
                        docker buildx version || true
REMOTE
                    '''
                }
            }
        }

        stage('Deploy to Docker-Server') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'], usernamePassword(credentialsId: DOCKERHUB_CRED_ID, usernameVariable: 'D_USER', passwordVariable: 'D_PASS')]) {
                    sh '''
                    set -e
                    REMOTE_IP=$(cat public_ip.txt)
                    SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                    REMOTE_DIR="/home/ec2-user/petclinic_deploy"

                    scp ${SSH_OPTS} docker-compose.yml ${SSH_USER}@${REMOTE_IP}:~/docker-compose.yml
                    scp -r ${SSH_OPTS} docker ${SSH_USER}@${REMOTE_IP}:~/docker

                    ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} bash -s <<'REMOTE'
                        set -euo pipefail
                        REMOTE_DIR="/home/ec2-user/petclinic_deploy"
                        D_USER="${D_USER:-}"
                        D_PASS="${D_PASS:-}"

                        set +u
                        source /etc/profile.d/docker-cli-plugins.sh 2>/dev/null || true
                        set -u

                        mkdir -p "$REMOTE_DIR"
                        rm -rf "$REMOTE_DIR/docker"
                        rm -f "$REMOTE_DIR/docker-compose.yml"

                        cp -r ~/docker "$REMOTE_DIR/"
                        cp ~/docker-compose.yml "$REMOTE_DIR/"

                        if [ -d ~/docker/prometheus ]; then
                            rm -rf "$REMOTE_DIR/prometheus"
                            mkdir -p "$REMOTE_DIR/prometheus"
                            cp ~/docker/prometheus/prometheus.yml "$REMOTE_DIR/prometheus/prometheus.yml"
                        fi

                        cd "$REMOTE_DIR"

                        if [ -n "$D_USER" ] && [ -n "$D_PASS" ]; then
                            printf "%s" "$D_PASS" | sudo -u "$USER" docker login -u "$D_USER" --password-stdin || true
                        fi

                        # Force remove any conflicting containers by name
                        # List all containers that may conflict with docker-compose services
                        echo "Removing conflicting containers..."
                        CONTAINERS="config-server discovery-server customers-service visits-service vets-service genai-service api-gateway tracing-server admin-server prometheus-server grafana-server"
                        
                        for container in $CONTAINERS; do
                            if sudo docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
                                echo "Stopping and removing container: $container"
                                sudo docker stop "$container" 2>/dev/null || true
                                sudo docker rm -f "$container" 2>/dev/null || true
                            fi
                        done

                        # Clean up any existing containers to avoid conflicts
                        echo "Cleaning up existing containers..."
                        sudo docker compose -p spring-petclinic down --remove-orphans 2>/dev/null || true
                        
                        # Also remove any orphaned containers not managed by compose
                        sudo docker container prune -f 2>/dev/null || true
                        
                        echo "Pulling latest images..."
                        sudo docker compose -p spring-petclinic pull || true
                        
                        echo "Starting services..."
                        sudo docker compose -p spring-petclinic up -d --build --remove-orphans
REMOTE
                    '''
                }
            }
        }

        stage('Verify Docker Deployment') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
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
                        sleep 30

                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8082/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "WARNING: visits-service health check failed (may still be starting)"
                        }

                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8083/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "WARNING: vets-service health check failed (may still be starting)"
                        }

                        echo ""
                        echo "=== Docker Deployment Verification Complete ==="
                        '''
                    }
                }
            }
        }

        stage('Configure MySQL Database') {
            when {
                expression { return params.CONFIGURE_MYSQL }
            }
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'mysql-root-credentials', 
                                usernameVariable: 'MYSQL_ROOT_USER', 
                                passwordVariable: 'MYSQL_ROOT_PASSWORD'),
                    usernamePassword(credentialsId: 'mysql-petclinic-credentials', 
                                usernameVariable: 'MYSQL_PETCLINIC_USER', 
                                passwordVariable: 'MYSQL_PETCLINIC_PASSWORD')
                ]) {
                    script {
                        echo "Configuring MySQL databases..."
                        
                        dir('ansible') {
                            sh '''
                                set -e
                                
                                echo "=== MySQL Configuration ==="
                                
                                # Test connectivity
                                ansible mysql -i inventory.ini -m ping || {
                                    echo "ERROR: Cannot connect to MySQL server"
                                    exit 1
                                }
                                
                                # Run manual playbook (NOT Galaxy role)
                                ansible-playbook -i inventory.ini mysql_setup.yml -v \
                                    -e "mysql_root_password='${MYSQL_ROOT_PASSWORD}'" \
                                    -e "mysql_petclinic_password='${MYSQL_PETCLINIC_PASSWORD}'"
                                
                                echo "✓ MySQL configuration complete"
                            '''
                        }
                    }
                }
            }
        }

        stage('Setup Kubernetes Master') {
            when {
                expression { 
                    return params.DEPLOYMENT_TARGET == 'kubernetes' || params.DEPLOYMENT_TARGET == 'both' 
                }
            }
            steps {
                script {
                    echo "Setting up Kubernetes master node..."
                    
                    dir('ansible') {
                        sh '''
                            set -e
                            
                            echo "=== Kubernetes Master Setup ==="
                            
                            # Test connectivity to K8s master
                            ansible k8s_master -i inventory.ini -m ping || {
                                echo "ERROR: Cannot connect to K8s master"
                                exit 1
                            }
                            
                            # Run K8s master playbook
                            ansible-playbook -i inventory.ini playbooks/k8s-master.yml -v
                            
                            echo "✓ Kubernetes master setup complete"
                        '''
                    }
                }
            }
        }

        stage('Setup Kubernetes Workers') {
            steps {
                script {
                    echo "Setting up Kubernetes worker nodes..."
                    
                    dir('ansible') {
                        sh '''
                            set -e
                            
                            echo "=== Kubernetes Workers Setup ==="
                            
                            # Test connectivity to K8s workers
                            ansible k8s_primary_workers:k8s_secondary_workers -i inventory.ini -m ping || {
                                echo "ERROR: Cannot connect to K8s workers"
                                exit 1
                            }
                            
                            # Run K8s workers playbook
                            ansible-playbook -i inventory.ini playbooks/k8s-workers.yml -v
                            
                            echo "✓ Kubernetes workers setup complete"
                        '''
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Deploying Spring Petclinic to Kubernetes..."
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP from inventory
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')

                            if [ -z "$K8S_MASTER_IP" ]; then
                                echo "ERROR: Could not find K8s master IP in inventory"
                                exit 1
                            fi
                            
                            echo "K8s Master IP: $K8S_MASTER_IP"
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            
                            echo "=== Copying Kubernetes manifests ==="
                            scp -r ${SSH_OPTS} kubernetes/ ${SSH_USER}@${K8S_MASTER_IP}:~/
                            
                            echo "=== Deploying to Kubernetes ==="
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} bash -s << 'REMOTE_K8S'
                                set -e
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                
                                echo "Verifying cluster status..."
                                kubectl get nodes
                                
                                echo "Applying Kubernetes manifests..."
                                cd ~/kubernetes/base/deployments
                                
                                # Deploy the complete manifest
                                kubectl apply -f deployment.yaml
                                
                                echo "Waiting for pods to be ready..."
                                kubectl wait --for=condition=ready pod -l app=config-server --timeout=300s || true
                                kubectl wait --for=condition=ready pod -l app=discovery-server --timeout=300s || true
                                
                                echo "Cluster status:"
                                kubectl get pods -o wide
                                kubectl get svc
                                
                                echo "✓ Kubernetes deployment complete"
REMOTE_K8S
                        '''
                    }
                }
            }
        }

        stage('Verify Kubernetes Deployment') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Verifying Kubernetes deployment..."
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')
                            
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            
                            echo "=== Kubernetes Cluster Status ==="
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} "
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                echo '--- Nodes ---'
                                kubectl get nodes -o wide
                                echo ''
                                echo '--- Pods ---'
                                kubectl get pods -o wide
                                echo ''
                                echo '--- Services ---'
                                kubectl get svc
                                echo ''
                                echo '--- API Gateway NodePort URL ---'
                                NODE_PORT=\$(kubectl get svc api-gateway -o jsonpath='{.spec.ports[0].nodePort}')
                                NODE_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"ExternalIP\")].address}')
                                if [ -z \"\$NODE_IP\" ]; then
                                    NODE_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}')
                                fi
                                echo \"Access application at: http://\${NODE_IP}:\${NODE_PORT}\"
                            "
                            
                            echo "✓ Kubernetes verification complete"
                        '''
                    }
                }
            }
        }

        stage('Install ArgoCD') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Installing ArgoCD on Kubernetes Master..."
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')
                            
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} bash -s << 'REMOTE'
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                
                                echo "Creating ArgoCD namespace..."
                                kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
                                
                                echo "Installing ArgoCD manifests..."
                                kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
                                
                                echo "Patching ArgoCD Server to use NodePort for access..."
                                kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

                                echo "Waiting for ArgoCD server components..."
                                kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=90s || echo "ArgoCD still starting up..."

                                echo ""
                                echo "=== ArgoCD Access Info ==="
                                NODE_PORT=\$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')
                                MASTER_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"ExternalIP\")].address}')
                                if [ -z "\$MASTER_IP" ]; then
                                    MASTER_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}')
                                fi
                                echo "URL: https://\$MASTER_IP:\$NODE_PORT"
                                echo ""
                                echo "=== Initial Admin Password ==="
                                echo "Run the following command to get the password:"
                                echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
REMOTE
                        '''
                    }
                }
            }
        }

        stage('Deploy to ArgoCD') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Registering ArgoCD Applications for environment: ${params.ENVIRONMENT}"
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')
                            
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            ENV="${ENVIRONMENT}"
                            
                            # Copy all ArgoCD manifests to the master
                            scp ${SSH_OPTS} kubernetes/argocd/*.yaml ${SSH_USER}@${K8S_MASTER_IP}:~/
                            
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} bash -s << END_SSH
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                ENV="${ENVIRONMENT}"
                                
                                echo "Applying ArgoCD Application Manifests..."
                                
                                if [ "\$ENV" = "all" ] || [ "\$ENV" = "dev" ]; then
                                    echo "Deploying DEV..."
                                    kubectl apply -f ~/dev-application.yaml
                                fi
                                
                                if [ "\$ENV" = "all" ] || [ "\$ENV" = "staging" ]; then
                                    echo "Deploying STAGING..."
                                    kubectl apply -f ~/staging-application.yaml
                                fi
                                
                                if [ "\$ENV" = "all" ] || [ "\$ENV" = "prod" ]; then
                                    echo "Deploying PROD..."
                                    kubectl apply -f ~/prod-application.yaml
                                fi
                                
                                echo "Applications registered!"
                                echo "Check status with: kubectl get application -n argocd"
END_SSH
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
