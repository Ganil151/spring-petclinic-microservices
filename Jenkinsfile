pipeline {
    agent any

    environment {
        // AWS & General Config
        AWS_REGION   = 'us-east-1'
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
        string(name: 'ECR_REGISTRY', defaultValue: 'REPLACE_WITH_YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com', description: 'ECR Registry URL')
        string(name: 'DOCKER_CREDENTIALS_ID', defaultValue: 'dockerhub-credentials', description: 'Docker Hub credentials ID')
        string(name: 'GITHUB_CREDENTIALS_ID', defaultValue: 'github-credentials', description: 'GitHub credentials ID')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                node(params.NODE_LABEL ?: 'worker-node') {
                    git branch: 'main',
                        credentialsId: params.GITHUB_CREDENTIALS_ID,
                        url: 'https://github.com/Ganil151/spring-petclinic-microservices.git'
                }
            }
        }

        stage('🛠️ Initialization') {
            steps {
                node(params.NODE_LABEL ?: 'worker-node') {
                    script {
                        echo "🚀 Starting CI/CD Pipeline for ${PROJECT_NAME}"
                        sh "./mvnw -version"
                        sh "docker --version"
                    }
                }
            }
        }

        stage('📦 Build & Unit Tests') {
            steps {
                node(params.NODE_LABEL ?: 'worker-node') {
                    sh "./mvnw clean install -DskipTests=false"
                }
            }
        }

        stage('🐳 Docker Build & Push') {
            steps {
                node(params.NODE_LABEL ?: 'worker-node') {
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
                                -t ${params.ECR_REGISTRY}/${serviceName}:latest \
                                -t ${params.ECR_REGISTRY}/${serviceName}:${env.BUILD_NUMBER} \
                                ."
                            
                            echo "📤 Pushing ${serviceName} to ECR..."
                            // sh "aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${params.ECR_REGISTRY}"
                            // sh "docker push ${params.ECR_REGISTRY}/${serviceName}:latest"
                            // sh "docker push ${params.ECR_REGISTRY}/${serviceName}:${env.BUILD_NUMBER}"
                        }
                    }
                }
            }
        stage('🚀 Deployment') {
            steps {
                node(params.NODE_LABEL ?: 'worker-node') {
                    script {
                        echo "🚀 Deploying ${PROJECT_NAME} to EKS (Staging)..."
                        // sh "helm upgrade --install ${PROJECT_NAME} ./kubernetes/helm-charts --namespace staging --set image.tag=${env.BUILD_NUMBER}"
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
