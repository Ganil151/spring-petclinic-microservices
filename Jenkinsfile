pipeline {
    agent {
        node {
            label params.NODE_LABEL ?: 'worker-node'
            customWorkspace "/home/ec2-user/workspace/spring-petclinic-microservices"
        }
    }

    environment {
        PROJECT_NAME = 'spring-petclinic'
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'NODE_LABEL', defaultValue: 'worker-node', description: 'Node label to run the build on')
        string(name: 'DOCKER_CREDENTIALS_ID', defaultValue: 'dockerhub-credentials', description: 'Docker Hub credentials ID')
        string(name: 'GITHUB_CREDENTIALS_ID', defaultValue: 'github-credentials', description: 'GitHub credentials ID')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('🛠️ Initialization') {
            steps {
                script {
                    echo "🚀 Starting CI/CD Pipeline for ${PROJECT_NAME}"
                    sh "git --version"
                    sh "docker --version"
                    
                    if (!commandExists('yq')) {
                        echo "Installing yq..."
                        sh '''
                        sudo wget https://github.com/mikefarah/yq/releases/download/v4.34.1/yq_linux_amd64 -O /usr/local/bin/yq
                        sudo chmod +x /usr/local/bin/yq
                        '''
                    }
                }
            }
        }

        stage('📦 Prep & Build') {
            steps {
                script {
                    echo "🧹 Cleaning up environments..."
                    sh '''
                    if [ -f docker-compose.yml ]; then
                        cp docker-compose.yml docker-compose.yml.bak
                        yq eval 'del(.services.genai-service)' -i docker-compose.yml
                    fi
                    '''
                    
                    echo "Building applications..."
                    sh "./mvnw clean install -DskipTests=false"
                }
            }
        }

        stage('🐳 Docker Build') {
            steps {
                script {
                    def services = [
                        'spring-petclinic-config-server': 8888,
                        'spring-petclinic-discovery-server': 8761,
                        'spring-petclinic-customers-service': 8081,
                        'spring-petclinic-vets-service': 8083,
                        'spring-petclinic-visits-service': 8082,
                        'spring-petclinic-genai-service': 8090,
                        'spring-petclinic-api-gateway': 8080,
                        'spring-petclinic-admin-server': 9090
                    ]

                    services.each { serviceName, port ->
                        echo "🏗️ Building Docker image for ${serviceName}..."
                        sh "docker build -f docker/Dockerfile \
                            --build-arg ARTIFACT_NAME=${serviceName}/target/${serviceName}-4.0.1 \
                            --build-arg EXPOSED_PORT=${port} \
                            -t ${serviceName}:latest \
                            -t ${serviceName}:${env.BUILD_NUMBER} \
                            ."
                    }
                }
            }
        }

        stage('🚀 Deployment') {
            steps {
                script {
                    echo "🚀 Deploying ${PROJECT_NAME} to EKS (Staging)..."
                    // sh "helm upgrade --install ${PROJECT_NAME} ./kubernetes/helm-charts --namespace staging --set image.tag=${env.BUILD_NUMBER}"
                }
            }
        }
    }

    post {
        always {
            echo "🏁 Pipeline Finished"
        }
        success {
            echo "✅ Build Successful!"
        }
        failure {
            echo "❌ Build Failed. Please check the logs."
        }
    }
}

def commandExists(String command) {
    return sh(script: "command -v ${command} >/dev/null 2>&1", returnStatus: true) == 0
}
