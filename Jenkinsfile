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
        ANSIBLE_INVENTORY    = "ansible/inventory.ini"
        MYSQL_SCHEMA_PATH    = "ansible/files/mysql_schema.sql"
        MYSQL_ROOT_CREDENTIALS_ID = "mysql-root-credentials"
        MYSQL_PETCLINIC_CREDENTIALS_ID = "mysql-petclinic-credentials"
    }

    parameters {
        string(name: 'NODE_LABEL', defaultValue: 'worker-node', description: 'Jenkins agent label')
        string(name: 'EC2_INSTANCE_NAME', defaultValue: 'Spring-Petclinic-Docker', description: 'EC2 instance tag Name')
        string(name: 'SSH_CREDENTIALS_ID', defaultValue: 'master_keys', description: 'SSH credentials ID for EC2 instances')
        choice(name: 'DEPLOYMENT_TARGET', choices: ['docker', 'kubernetes', 'both', 'none'], description: 'Deployment target')
        booleanParam(name: 'CONFIGURE_MYSQL', defaultValue: true, description: 'Run Ansible to configure MySQL databases')
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
                    [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'],
                    usernamePassword(credentialsId: env.MYSQL_ROOT_CREDENTIALS_ID, usernameVariable: 'MYSQL_ROOT_USER', passwordVariable: 'MYSQL_ROOT_PASSWORD'),
                    usernamePassword(credentialsId: env.MYSQL_PETCLINIC_CREDENTIALS_ID, usernameVariable: 'MYSQL_PETCLINIC_USER', passwordVariable: 'MYSQL_PETCLINIC_PASSWORD')
                ]) {
                    script {
                        echo "Configuring MySQL databases with Ansible..."
                        
                        // Run from the ansible directory
                        dir('ansible') {
                            // First, create the group_vars file
                            sh '''
                                set -euo pipefail
                                echo "=========================================="
                                echo "MySQL Configuration - Creating Variables"
                                echo "=========================================="
                                
                                # Ensure ansible directory structure exists
                                mkdir -p group_vars files roles
                                
                                # Create group_vars/mysql.yml using Ansible lookups for safety
                                cat > group_vars/mysql.yml << 'ENDOFVARS'
---
mysql_root_password: "{{ lookup('env', 'MYSQL_ROOT_PASSWORD') }}"
mysql_petclinic_password: "{{ lookup('env', 'MYSQL_PETCLINIC_PASSWORD') }}"
mysql_database_name: "petclinic"
mysql_user_name: "{{ lookup('env', 'MYSQL_PETCLINIC_USER') }}"
mysql_user_password: "{{ lookup('env', 'MYSQL_PETCLINIC_PASSWORD') }}"

petclinic_databases:
- customers
- visits
- vets
ENDOFVARS
                                
                                echo "✓ Ansible variables configured"
                            '''
                            
                            // Test connectivity
                            sh '''
                                set -euo pipefail
                                echo ""
                                echo "=== Testing Ansible Connectivity ==="
                                
                                if ansible mysql -i inventory.ini -m ping; then
                                    echo "✓ Ansible connectivity verified"
                                else
                                    echo "ERROR: Cannot connect to MySQL server via Ansible"
                                    echo "Checking inventory file..."
                                    cat inventory.ini || echo "inventory.ini not found"
                                    exit 1
                                fi
                            '''
                            
                            // Run diagnostic playbook
                            sh '''
                                set -euo pipefail
                                echo ""
                                echo "=========================================="
                                echo "MySQL Configuration - Phase 2: Diagnostics"
                                echo "=========================================="
                                
                                # Export environment variables for Ansible lookups
                                export MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
                                export MYSQL_PETCLINIC_PASSWORD="${MYSQL_PETCLINIC_PASSWORD}"
                                export MYSQL_PETCLINIC_USER="${MYSQL_PETCLINIC_USER}"
                                
                                # Check if diagnostic playbook exists
                                if [ -f mysql_diagnostic.yml ]; then
                                    echo "Running diagnostic playbook..."
                                    ansible-playbook -i inventory.ini mysql_diagnostic.yml || {
                                        echo "WARNING: Diagnostic playbook failed (may be expected)"
                                    }
                                else
                                    echo "WARNING: mysql_diagnostic.yml not found, skipping diagnostics"
                                fi
                            '''
                            
                            // Run setup playbook
                            def setupSuccess = false
                            try {
                                sh '''
                                    set -euo pipefail
                                    echo ""
                                    echo "=========================================="
                                    echo "MySQL Configuration - Phase 3: Setup"
                                    echo "=========================================="
                                    
                                    # Export environment variables for Ansible lookups
                                    export MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
                                    export MYSQL_PETCLINIC_PASSWORD="${MYSQL_PETCLINIC_PASSWORD}"
                                    export MYSQL_PETCLINIC_USER="${MYSQL_PETCLINIC_USER}"
                                    
                                    # Check if setup playbook exists
                                    if [ ! -f mysql_setup.yml ]; then
                                        echo "ERROR: mysql_setup.yml not found"
                                        echo "Available files:"
                                        ls -la
                                        exit 1
                                    fi
                                    
                                    # Run mysql_setup.yml
                                    ansible-playbook -i inventory.ini mysql_setup.yml -v
                                '''
                                setupSuccess = true
                            } catch (Exception e) {
                                echo "Setup failed with error: ${e.message}"
                                echo "Attempting to reset MySQL..."
                                
                                // Try reset if setup failed
                                try {
                                    sh '''
                                        set -euo pipefail
                                        echo ""
                                        echo "=========================================="
                                        echo "Attempting MySQL Reset"
                                        echo "=========================================="
                                        
                                        # Export environment variables for Ansible lookups
                                        export MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
                                        export MYSQL_PETCLINIC_PASSWORD="${MYSQL_PETCLINIC_PASSWORD}"
                                        export MYSQL_PETCLINIC_USER="${MYSQL_PETCLINIC_USER}"
                                        
                                        if [ -f reset_mysql.yml ]; then
                                            ansible-playbook -i inventory.ini reset_mysql.yml -v \
                                                -e "force_reset=yes"
                                            
                                            echo ""
                                            echo "Reset complete. Retrying setup..."
                                            
                                            ansible-playbook -i inventory.ini mysql_setup.yml -v
                                        else
                                            echo "ERROR: reset_mysql.yml not found"
                                            exit 1
                                        fi
                                    '''
                                    setupSuccess = true
                                } catch (Exception resetError) {
                                    echo "Reset and retry failed: ${resetError.message}"
                                    error("MySQL setup failed. Check password policy compliance.")
                                }
                            }
                            
                            // Verify databases
                            if (setupSuccess) {
                                sh '''
                                    set -euo pipefail
                                    echo ""
                                    echo "=========================================="
                                    echo "MySQL Configuration - Phase 4: Verification"
                                    echo "=========================================="
                                    
                                    # Verify databases were created
                                    echo "=== Verifying Database Creation ==="
                                    
                                    # Get database list using simple approach
                                    DB_OUTPUT=$(ansible mysql -i inventory.ini -m shell \
                                        -a "/usr/bin/mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e 'SHOW DATABASES;' -N -B 2>/dev/null || echo 'ERROR'" \
                                        2>&1 || echo "ANSIBLE_FAILED")
                                    
                                    echo "Database check output:"
                                    echo "$DB_OUTPUT"
                                    echo ""
                                    
                                    # Check for required databases
                                    MISSING=""
                                    for db in petclinic_customers petclinic_visits petclinic_vets; do
                                        if echo "$DB_OUTPUT" | grep -q "$db"; then
                                            echo "✓ Database $db exists"
                                        else
                                            echo "✗ Database $db is MISSING"
                                            MISSING="$MISSING $db"
                                        fi
                                    done
                                    
                                    if [ -n "$MISSING" ]; then
                                        echo ""
                                        echo "ERROR: The following databases are missing:$MISSING"
                                        echo ""
                                        echo "Troubleshooting:"
                                        echo "1. Check if password meets MySQL 8.x requirements:"
                                        echo "   - Minimum 8 characters"
                                        echo "   - At least 1 uppercase letter"
                                        echo "   - At least 1 lowercase letter"
                                        echo "   - At least 1 number"
                                        echo "   - At least 1 special character"
                                        echo ""
                                        echo "2. Update Jenkins credentials (Recommended):"
                                        echo "   - Go to: Jenkins → Manage Jenkins → Credentials"
                                        echo "   - Update 'mysql-root-credentials'"
                                        echo "   - Use password like: Petclinic2025!"
                                        echo ""
                                        exit 1
                                    fi
                                    
                                    echo ""
                                    echo "✓ All required databases exist"
                                    
                                    # Verify user
                                    echo ""
                                    echo "=== Verifying Petclinic User ==="
                                    
                                    USER_OUTPUT=$(ansible mysql -i inventory.ini -m shell \
                                        -a "/usr/bin/mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e \"SELECT User,Host FROM mysql.user WHERE User='${MYSQL_PETCLINIC_USER}';\" -N -B 2>/dev/null || echo 'ERROR'" \
                                        2>&1 || echo "ANSIBLE_FAILED")
                                    
                                    if echo "$USER_OUTPUT" | grep -q "${MYSQL_PETCLINIC_USER}"; then
                                        echo "✓ User '${MYSQL_PETCLINIC_USER}' exists"
                                    else
                                        echo "WARNING: Could not verify user (may still exist)"
                                    fi
                                    
                                    # Get MySQL server info
                                    MYSQL_IP=$(grep "mysql" inventory.ini | grep "ansible_host" | awk '{print $2}' | cut -d'=' -f2 || echo "Unknown")
                                    
                                    echo ""
                                    echo "=========================================="
                                    echo "MySQL Configuration Complete!"
                                    echo "=========================================="
                                    echo "✓ Databases: petclinic_customers, petclinic_visits, petclinic_vets"
                                    echo "✓ User: ${MYSQL_PETCLINIC_USER}"
                                    echo "✓ Connection: ${MYSQL_IP}:3306"
                                    echo "✓ All health checks passed"
                                    echo "=========================================="
                                '''
                            }
                        }
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
