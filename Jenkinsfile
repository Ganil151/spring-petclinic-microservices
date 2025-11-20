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

                JAR=$(ls spring-petclinic-config-server/target/*.jar 2>/dev/null | head -n1 || true)
                if [ -z "$JAR" ]; then
                    echo "ERROR: built jar not found"
                    exit 2
                fi
                mkdir -p docker
                cp "$JAR" docker/application.jar
                '''
            }
        }
        
        stage('Docker Build & Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: DOCKERHUB_CRED_ID, usernameVariable: 'D_USER', passwordVariable: 'D_PASS')]) {
                    sh '''
                    set -e
                    echo "$D_PASS" | docker login -u "$D_USER" --password-stdin

                    cd docker
                    docker build --no-cache --pull --build-arg JAR_FILE=application.jar -t ${DOCKER_IMAGE}:${IMAGE_TAG} -t ${DOCKER_IMAGE}:latest -f Dockerfile .
                    for tag in "${IMAGE_TAG}" "latest"; do
                        n=0
                        until [ $n -ge 3 ]
                        do
                            docker push ${DOCKER_IMAGE}:$tag && break
                            n=$((n+1))
                            echo "Retrying push (${n})..."
                            sleep 5
                        done
                        if [ $n -ge 3 ]; then
                            echo "Failed to push ${DOCKER_IMAGE}:$tag after retries"
                            exit 1
                        fi
                    done
                    '''
                }
            }
        }

        stage('Provision or Reuse Docker-Server') {
            steps {
                script {
                    def instanceId = ''
                    def state = ''
                    def publicIp = ''
                    env.IS_NEW_INSTANCE = 'false' 

                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDENTIALS_ID]]) {
                        echo "Looking up EC2 instance by Name tag: ${env.EC2_INSTANCE_NAME}"

                        instanceId = sh(
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
                                        --instance-type c7i-flex.large \\
                                        --key-name master_keys \\
                                        --security-group-ids sg-00c6bccfbdec3bb9d \\
                                        --subnet-id subnet-0e2489f42748d00f3 \\
                                        --associate-public-ip-address \\
                                        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${env.EC2_INSTANCE_NAME}}]" \\
                                        --query "Instances[0].InstanceId" --output text
                                """
                            ).trim()

                            echo "Launched: ${instanceId}"
                            env.IS_NEW_INSTANCE = 'true' // Set flag for conditional bootstrap
                            state = 'pending' 
                        } else {
                            instanceId = instanceId.split('\\s+')[0] // Take only the first ID
                            state = sh(
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

                        if (state != "running") {
                            echo "Waiting for instance to enter running state..."
                            sh "aws ec2 wait instance-running --region ${env.EC2_REGION} --instance-ids ${instanceId}"
                        }
                        
                        publicIp = sh(
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
            when {
                expression { env.IS_NEW_INSTANCE == 'true' }
            }
            steps {
                echo "Running Bootstrap: Instance is new, installing dependencies..."
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

                        # Java & Maven
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
            stash includes: 'public_ip.txt', name: 'public_ip' // keep for downstream pipelines
        }
    }
}