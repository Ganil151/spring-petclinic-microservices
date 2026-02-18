pipeline {
    agent {
        node {
            label params.NODE_LABEL ?: 'worker-node'
            customWorkspace "/home/ec2-user/workspace/spring-petclinic-microservices"
        }
    }

    environment {
        PROJECT_NAME = 'spring-petclinic'
        AWS_REGION   = 'us-east-1'
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'NODE_LABEL', defaultValue: 'worker-node', description: 'Node label to run the build on')
        string(name: 'ECR_REGISTRY', defaultValue: 'REPLACE_WITH_YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com', description: 'ECR Registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com)')
        string(name: 'DOCKER_CREDENTIALS_ID', defaultValue: 'dockerhub-credentials', description: 'Docker Hub credentials ID')
        string(name: 'GITHUB_CREDENTIALS_ID', defaultValue: 'github-credentials', description: 'GitHub credentials ID')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: params.GITHUB_CREDENTIALS_ID,
                    url: 'https://github.com/Ganil151/spring-petclinic-microservices.git'
            }
        }

        stage('🛠️ Environment Setup') {
            steps {
                script {
                    echo "🔧 Preparing environment..."
                    sh "chmod +x mvnw"
                    
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

        stage('🧹 Prep Files') {
            steps {
                script {
                    echo "📂 Removing genai-service from docker-compose..."
                    sh '''
                    if [ -f docker-compose.yml ]; then
                        cp docker-compose.yml docker-compose.yml.bak
                        yq eval 'del(.services.genai-service)' -i docker-compose.yml
                    fi
                    '''
                }
            }
        }

        stage('📦 Build Application') {
            steps {
                script {
                    echo "🏗️ Building the Spring PetClinic application..."
                    sh './mvnw clean package -DskipTests'
                }
            }
        }

        stage('🧪 Run Unit Tests') {
            steps {
                script {
                    echo "🔍 Running unit tests..."
                    sh './mvnw test'
                }
            }
        }

        stage('🐳 Docker Build & Push') {
            steps {
                script {
                    echo "🔐 Logging into Amazon ECR..."
                    sh "aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${params.ECR_REGISTRY}"

                    def services = [
                        'spring-petclinic-config-server': 8888,
                        'spring-petclinic-discovery-server': 8761,
                        'spring-petclinic-customers-service': 8081,
                        'spring-petclinic-vets-service': 8083,
                        'spring-petclinic-visits-service': 8082,
                        'spring-petclinic-api-gateway': 8080,
                        'spring-petclinic-admin-server': 9090
                    ]

                    services.each { serviceName, port ->
                        echo "🏗️ Building Docker image for ${serviceName}..."
                        def imageTagLatest = "${params.ECR_REGISTRY}/${serviceName}:latest"
                        def imageTagBuild = "${params.ECR_REGISTRY}/${serviceName}:${env.BUILD_NUMBER}"

                        sh "docker build -f docker/Dockerfile \
                            --build-arg ARTIFACT_NAME=${serviceName}/target/${serviceName}-4.0.1 \
                            --build-arg EXPOSED_PORT=${port} \
                            -t ${imageTagLatest} \
                            -t ${imageTagBuild} \
                            ."
                        
                        echo "📤 Pushing ${serviceName} to ECR..."
                        sh "docker push ${imageTagLatest}"
                        sh "docker push ${imageTagBuild}"
                    }
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
