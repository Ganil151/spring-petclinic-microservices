pipeline {
    agent { label params.NODE_LABEL}

    environment {
        // AWS & General Config
        AWS_REGION      = 'us-east-1' // Adjust as needed
        PROJECT_NAME    = 'spring-petclinic'
        DOCKER_CREDENTIALS_ID = params.DOCKER_CREDENTIALS_ID
        GITHUB_CREDENTIALS_ID = params.GITHUB_CREDENTIALS_ID

        
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'NODE_LABEL', defaultValue: 'worker-node', description: 'Node label to run the build on')
        string(name: 'DOCKER_CREDENTIALS_ID', defaultValue: 'dockerhub-credentials', description: 'dockerhub-credentials')
        string(name: 'GITHUB_CREDENTIALS_ID', defaultValue: 'github-credentials', description: 'github-credentials id')
    }

    stages {
        stage('🛠️ Initialization') {
            steps {
                script {
                    echo "🚀 Starting CI/CD Pipeline for ${PROJECT_NAME}"
                    sh "${MAVEN_HOME}/bin/mvn -version"
                    sh "docker --version"
                    sh "trivy --version"
                }
            }
        }

        stage('🔍 Static Code Analysis') {
            parallel {
                stage('SonarQube Analysis') {
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh "${MAVEN_HOME}/bin/mvn sonar:sonar \
                                -Dsonar.projectKey=${PROJECT_NAME} \
                                -Dsonar.host.url=${SONAR_URL}"
                        }
                        timeout(time: 10, unit: 'MINUTES') {
                            waitForQualityGate abortPipeline: true
                        }
                    }
                }
                stage('IaC & Security Scanning') {
                    steps {
                        script {
                            echo "🛡️ Running Trivy Scan on project root..."
                            sh "trivy fs --security-checks config,vuln . --exit-code 0"
                            
                            echo "🛡️ Running Checkov on Terraform code..."
                            sh "checkov -d terraform/ --soft-fail"
                        }
                    }
                }
            }
        }

        stage('📦 Build & Unit Tests') {
            steps {
                sh "${MAVEN_HOME}/bin/mvn clean install -DskipTests=false"
            }
        }

        stage('🐳 Docker Build & Push') {
            steps {
                script {
                    // ECR Login (Using the EC2 Instance Profile)
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"

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
                        def ecrRepoName = serviceName.replace('spring-petclinic-', '')
                        stage("Build: ${serviceName}") {
                            echo "Building Docker image for ${serviceName}..."
                            sh "docker build -f docker/Dockerfile \
                                --build-arg ARTIFACT_NAME=${serviceName}/target/${serviceName}-4.0.1 \
                                --build-arg EXPOSED_PORT=${port} \
                                -t ${ECR_REGISTRY}/${PROJECT_NAME}-dev-${ecrRepoName}:latest \
                                -t ${ECR_REGISTRY}/${PROJECT_NAME}-dev-${ecrRepoName}:${BUILD_NUMBER} \
                                ."
                            
                            echo "Pushing ${serviceName} to ECR..."
                            sh "docker push ${ECR_REGISTRY}/${PROJECT_NAME}-dev-${ecrRepoName}:latest"
                            sh "docker push ${ECR_REGISTRY}/${PROJECT_NAME}-dev-${ecrRepoName}:${BUILD_NUMBER}"
                        }
                    }
                }
            }
        }

        stage('🚀 Deployment') {
            parallel {
                stage('Deploy to EKS (Staging)') {
                    steps {
                        script {
                            echo "Deploying to EKS via Helm..."
                            sh "helm upgrade --install ${PROJECT_NAME} ./kubernetes/helm-charts/spring-petclinic \
                                --namespace staging \
                                --create-namespace \
                                --set global.imageRegistry=${ECR_REGISTRY} \
                                --set Chart.AppVersion=${BUILD_NUMBER}"
                        }
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
