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
        K8S_MASTER_IP        = "${params.K8S_MASTER_IP ?: ''}"
        SECURITY_GROUP_ID    = "${params.SECURITY_GROUP_ID ?: ''}"
        SUBNET_ID            = "${params.SUBNET_ID ?: ''}"
        AMI_ID               = "${params.AMI_ID ?: ''}"
        INSTANCE_TYPE        = "${params.INSTANCE_TYPE ?: ''}"
        ANSIBLE_INVENTORY    = "ansible/inventory.ini"
        MYSQL_SCHEMA_PATH    = "ansible/files/mysql_schema.sql" // adjust to where your SQL lives
        MYSQL_ROOT_CREDENTIALS_ID = "mysql-root-credentials"
        MYSQL_PETCLINIC_CREDENTIALS_ID = "mysql-petclinic-credentials"
    }

    parameters {
        string(name: 'NODE_LABEL', defaultValue: 'worker-node', description: 'Jenkins agent label')
        string(name: 'EC2_INSTANCE_NAME', defaultValue: 'Spring-Petclinic-Docker', description: 'EC2 instance tag Name')
        string(name: 'K8S_MASTER_IP', defaultValue: '', description: 'Kubernetes Master IP (auto-detected from Terraform/Ansible if empty)')
        string(name: 'SSH_CREDENTIALS_ID', defaultValue: 'master_keys', description: 'SSH credential id for EC2')
        string(name: 'SECURITY_GROUP_ID', defaultValue: '', description: 'Security Group ID for EC2')
        string(name: 'SUBNET_ID', defaultValue: '', description: 'Subnet ID for EC2')
        string(name: 'AMI_ID', defaultValue: '', description: 'AMI ID for EC2')
        string(name: 'INSTANCE_TYPE', defaultValue: '', description: 'Instance Type for EC2')
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
                                        --image-id ${env.AMI_ID} \\
                                        --instance-type ${env.INSTANCE_TYPE} \\
                                        --key-name ${env.SSH_CREDENTIALS_ID} \\
                                        --security-group-ids ${env.SECURITY_GROUP_ID} \\
                                        --subnet-id ${env.SUBNET_ID} \\
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

                        sudo docker compose -p spring-petclinic pull || true
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
                            sh '''
                            set -euo pipefail

                            echo "=========================================="
                            echo "MySQL Configuration - Phase 1: Diagnostics"
                            echo "=========================================="
                            echo ""

                            # Ensure ansible directory structure exists
                            mkdir -p group_vars files roles

                            # Update Ansible group_vars with credentials from Jenkins
                            cat > group_vars/mysql.yml <<EOF
        ---
        mysql_root_password: "${MYSQL_ROOT_PASSWORD}"
        mysql_petclinic_password: "${MYSQL_PETCLINIC_PASSWORD}"
        mysql_database_name: "petclinic"
        mysql_user_name: "${MYSQL_PETCLINIC_USER}"
        mysql_user_password: "${MYSQL_PETCLINIC_PASSWORD}"

        petclinic_databases:
        - customers
        - visits
        - vets
        EOF

                            echo "✓ Ansible variables configured"
                            echo ""

                            # Test Ansible connectivity
                            echo "=== Testing Ansible Connectivity ==="
                            set +e
                            ansible mysql -i inventory.ini -m ping
                            PING_RC=$?
                            set -e
                            
                            if [ $PING_RC -ne 0 ]; then
                                echo "ERROR: Cannot connect to MySQL server via Ansible"
                                echo "Checking inventory file..."
                                cat inventory.ini
                                echo ""
                                echo "Checking SSH connectivity manually..."
                                MYSQL_HOST=$(grep "mysql" inventory.ini | awk '{print $2}' | cut -d'=' -f2)
                                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${SSH_KEY} ${SSH_USER}@${MYSQL_HOST} "echo 'SSH works'" || {
                                    echo "ERROR: Cannot SSH to MySQL server"
                                    exit 1
                                }
                                exit 1
                            fi
                            echo "✓ Ansible connectivity verified"
                            echo ""

                            # Define extra vars with proper escaping
                            EXTRA_VARS="mysql_root_password='${MYSQL_ROOT_PASSWORD}' mysql_petclinic_password='${MYSQL_PETCLINIC_PASSWORD}' mysql_user_name='${MYSQL_PETCLINIC_USER}'"

                            echo "=========================================="
                            echo "MySQL Configuration - Phase 2: Diagnostics"
                            echo "=========================================="
                            echo ""
                            
                            # Run diagnostic playbook first
                            set +e
                            ansible-playbook -i inventory.ini mysql_diagnostic.yml -e "$EXTRA_VARS" | tee diagnostic_output.log
                            DIAG_RC=$?
                            set -e
                            
                            echo ""
                            echo "Diagnostic completed with return code: $DIAG_RC"
                            echo ""

                            echo "=========================================="
                            echo "MySQL Configuration - Phase 3: Setup"
                            echo "=========================================="
                            echo ""

                            # Run mysql_setup.yml
                            set +e
                            ansible-playbook -i inventory.ini mysql_setup.yml -v -e "$EXTRA_VARS"
                            SETUP_RC=$?
                            set -e

                            # If setup failed, try reset and retry
                            if [ $SETUP_RC -ne 0 ]; then
                                echo ""
                                echo "=========================================="
                                echo "Setup failed. Analyzing error..."
                                echo "=========================================="
                                echo ""
                                
                                # Check if it's a password policy issue
                                if grep -q "password does not satisfy" diagnostic_output.log 2>/dev/null || \
                                grep -q "password does not satisfy" ~/.ansible.log 2>/dev/null; then
                                    echo "ERROR: Password Policy Violation Detected"
                                    echo ""
                                    echo "Your MySQL password does not meet the complexity requirements."
                                    echo "MySQL 8.x requires passwords with:"
                                    echo "  - Minimum 8 characters"
                                    echo "  - At least 1 uppercase letter"
                                    echo "  - At least 1 lowercase letter"
                                    echo "  - At least 1 number"
                                    echo "  - At least 1 special character"
                                    echo ""
                                    echo "Current password format is not compliant."
                                    echo ""
                                    echo "SOLUTION: Update Jenkins Credentials"
                                    echo "  1. Go to Jenkins → Manage Jenkins → Credentials"
                                    echo "  2. Update 'mysql-root-credentials'"
                                    echo "  3. Use format like: Petclinic2025!"
                                    echo ""
                                    exit 1
                                fi
                                
                                echo "Attempting MySQL reset..."
                                echo ""
                                
                                # Run reset playbook
                                ansible-playbook -i inventory.ini reset_mysql.yml -v -e "$EXTRA_VARS" -e "force_reset=yes"
                                
                                echo ""
                                echo "Reset complete. Retrying setup..."
                                echo ""
                                
                                # Retry setup
                                ansible-playbook -i inventory.ini mysql_setup.yml -v -e "$EXTRA_VARS"
                                SETUP_RC=$?
                                
                                if [ $SETUP_RC -ne 0 ]; then
                                    echo "ERROR: Setup failed even after reset"
                                    exit 1
                                fi
                            fi

                            echo ""
                            echo "✓ Ansible playbook completed successfully"
                            echo ""

                            echo "=========================================="
                            echo "MySQL Configuration - Phase 4: Verification"
                            echo "=========================================="
                            echo ""

                            # Verify databases were created
                            echo "=== Verifying Database Creation ==="
                            
                            # Get raw database list
                            DB_LIST=$(ansible mysql -i inventory.ini -m shell \
                                -a "mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e 'SHOW DATABASES;' -N -B 2>/dev/null" \
                                --one-line 2>&1 | grep -v "^mysql" | grep -v "CHANGED" || echo "")
                            
                            echo "Raw output from SHOW DATABASES:"
                            echo "$DB_LIST"
                            echo ""
                            
                            # Check each required database
                            MISSING=""
                            for db in petclinic_customers petclinic_visits petclinic_vets; do
                                if echo "$DB_LIST" | grep -q "$db"; then
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
                                echo "Troubleshooting steps:"
                                echo "1. Check Ansible playbook output above for errors"
                                echo "2. Verify MySQL root password in Jenkins credentials"
                                echo "3. Run diagnostic playbook: ansible-playbook -i inventory.ini mysql_diagnostic.yml"
                                echo "4. Check MySQL error log on the server: tail -50 /var/log/mysqld.log"
                                echo ""
                                exit 1
                            fi
                            
                            echo ""
                            echo "✓ All required databases exist"
                            echo ""

                            # Verify petclinic user
                            echo "=== Verifying Petclinic User ==="
                            USER_CHECK=$(ansible mysql -i inventory.ini -m shell \
                                -a "mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e \"SELECT User,Host FROM mysql.user WHERE User='${MYSQL_PETCLINIC_USER}';\" -N -B 2>/dev/null" \
                                --one-line 2>&1 | grep -v "^mysql" | grep -v "CHANGED" || echo "")
                            
                            if echo "$USER_CHECK" | grep -q "${MYSQL_PETCLINIC_USER}"; then
                                echo "✓ User '${MYSQL_PETCLINIC_USER}' exists"
                                echo "  Access from: $(echo "$USER_CHECK" | awk '{print $2}')"
                            else
                                echo "ERROR: User '${MYSQL_PETCLINIC_USER}' not found"
                                exit 1
                            fi
                            echo ""

                            # Test petclinic user connection
                            echo "=== Testing Petclinic User Connection ==="
                            set +e
                            ansible mysql -i inventory.ini -m shell \
                                -a "mysql -u${MYSQL_PETCLINIC_USER} -p'${MYSQL_PETCLINIC_PASSWORD}' -e 'SELECT 1;' 2>&1" \
                                --one-line | grep -q "SUCCESS" || grep -q "mysql"
                            USER_CONNECT_RC=$?
                            set -e
                            
                            if [ $USER_CONNECT_RC -eq 0 ]; then
                                echo "✓ User '${MYSQL_PETCLINIC_USER}' can connect"
                            else
                                echo "WARNING: Could not verify user connection (may still work)"
                            fi
                            echo ""

                            # Verify database access
                            echo "=== Verifying Database Access ==="
                            for db in customers visits vets; do
                                echo "Testing access to petclinic_$db..."
                                set +e
                                ansible mysql -i inventory.ini -m shell \
                                    -a "mysql -u${MYSQL_PETCLINIC_USER} -p'${MYSQL_PETCLINIC_PASSWORD}' -e 'USE petclinic_$db; SELECT 1;' 2>&1" \
                                    --one-line | grep -q "SUCCESS\\|mysql"
                                DB_ACCESS_RC=$?
                                set -e
                                
                                if [ $DB_ACCESS_RC -eq 0 ]; then
                                    echo "✓ Access to petclinic_$db verified"
                                else
                                    echo "WARNING: Could not verify access to petclinic_$db"
                                fi
                            done
                            echo ""

                            # Get MySQL server info
                            echo "=== MySQL Server Information ==="
                            MYSQL_VERSION=$(ansible mysql -i inventory.ini -m shell \
                                -a "mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e 'SELECT VERSION();' -N -B 2>/dev/null" \
                                --one-line 2>&1 | grep -v "^mysql" | grep -v "CHANGED" | head -1 || echo "Unknown")
                            echo "MySQL Version: $MYSQL_VERSION"
                            
                            MYSQL_IP=$(grep "mysql" inventory.ini | grep "ansible_host" | awk '{print $2}' | cut -d'=' -f2)
                            echo "MySQL Server IP: $MYSQL_IP"
                            echo "MySQL Port: 3306"
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
