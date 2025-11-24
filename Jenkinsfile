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
        IS_NEW_INSTANCE      = 'false' 
    }

    parameters {
        string(name: 'NODE_LABEL',        defaultValue: 'worker-node', description: 'Jenkins agent label')
        string(name: 'EC2_INSTANCE_NAME', defaultValue: 'Spring-Petclinic-Docker', description: 'EC2 instance tag Name')
        string(name: 'SSH_CREDENTIALS_ID', defaultValue: 'master_keys', description: 'SSH credential id for EC2')
    }
    
    // New parameters for MySQL configuration
    choice(
        name: 'DEPLOYMENT_TARGET',
        choices: ['docker', 'kubernetes', 'both', 'none'],
        description: 'Deployment target'
    )
    booleanParam(
        name: 'CONFIGURE_MYSQL',
        defaultValue: false,
        description: 'Run Ansible to configure MySQL databases'
    )

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
            when {
                expression { params.DEPLOYMENT_TARGET in ['docker', 'both'] }
            }
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
                        sleep 30
                        
                        echo ""
                        echo "=== Verifying service health endpoints ==="
                        
                        # Check config-server
                        echo "Checking config-server..."
                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8888/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "ERROR: config-server health check failed"
                            exit 1
                        }
                        echo "✓ config-server is UP"
                        
                        # Check discovery-server
                        echo "Checking discovery-server..."
                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8761/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "ERROR: discovery-server health check failed"
                            exit 1
                        }
                        echo "✓ discovery-server is UP"
                        
                        # Check api-gateway
                        echo "Checking api-gateway..."
                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8080/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "ERROR: api-gateway health check failed"
                            exit 1
                        }
                        echo "✓ api-gateway is UP"
                        
                        # Check customers-service
                        echo "Checking customers-service..."
                        ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8081/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                            echo "WARNING: customers-service health check failed (may still be starting)"
                        }
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
        when {
            expression { 
                params.DEPLOYMENT_TARGET in ['kubernetes', 'both'] &&
                params.CONFIGURE_MYSQL == true
            }
        }
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
                    ansible mysql -i inventory.ini -m shell \
                        -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SHOW DATABASES;'" \
                        | grep -E 'customers|visits|vets' || {
                        echo "ERROR: Required databases not found"
                        exit 1
                    }
                    echo "✓ All required databases exist (customers, visits, vets)"
                    echo ""
                    
                    # Verify petclinic user was created
                    echo "=== Verifying Petclinic User ==="
                    ansible mysql -i inventory.ini -m shell \
                        -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e \"SELECT User, Host FROM mysql.user WHERE User='${MYSQL_PETCLINIC_USER}';\"" \
                        | grep "${MYSQL_PETCLINIC_USER}" || {
                        echo "ERROR: Petclinic user not found"
                        exit 1
                    }
                    echo "✓ Petclinic user exists: ${MYSQL_PETCLINIC_USER}"
                    echo ""
                    
                    # Test petclinic user can connect
                    echo "=== Testing Petclinic User Connection ==="
                    ansible mysql -i inventory.ini -m shell \
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
                        ansible mysql -i inventory.ini -m shell \
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
                        TABLE_COUNT=$(ansible mysql -i inventory.ini -m shell \
                            -a "mysql -u ${MYSQL_PETCLINIC_USER} -p${MYSQL_PETCLINIC_PASSWORD} -e 'USE $db; SHOW TABLES;'" \
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
                    ansible mysql -i inventory.ini -m shell \
                        -a "mysql -u ${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e 'SELECT VERSION();'" \
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
        
    } // <--- End of stages block

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