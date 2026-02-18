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
        string(name: 'ECR_REGISTRY', defaultValue: '', description: 'ECR Registry URL (Leave blank to auto-detect)')
        string(name: 'GITHUB_CREDENTIALS_ID', defaultValue: 'github-credentials', description: 'GitHub credentials ID')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('🧹 Environment Cleanup') {
            steps {
                script {
                    echo "🧹 Cleaning up disk space..."
                    sh "df -h"
                    // Prune dangling images and build cache to free up space
                    sh "docker system prune -f --filter 'until=24h'"
                }
            }
        }

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
                    
                    echo "🕵️ Verifying AWS IAM Identity..."
                    sh "aws sts get-caller-identity"

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
                    // Resolve ECR Registry dynamically if not provided
                    def ecrRegistry = params.ECR_REGISTRY
                    if (!ecrRegistry) {
                        def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                        ecrRegistry = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                        echo "✨ Auto-detected ECR Registry: ${ecrRegistry}"
                    }

                    echo "🔐 Logging into Amazon ECR..."
                    sh "aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${ecrRegistry}"

                    def services = [
                        'config-server': 8888,
                        'discovery-server': 8761,
                        'customers-service': 8081,
                        'vets-service': 8083,
                        'visits-service': 8082,
                        'api-gateway': 8080,
                        'admin-server': 9090
                    ]

                    services.each { serviceShortName, port ->
                        def fullModuleName = "spring-petclinic-${serviceShortName}"
                        def repoName = "petclinic-dev-${serviceShortName}"
                        
                        echo "🏗️ Building Docker image for ${fullModuleName}..."
                        def imageTagLatest = "${ecrRegistry}/${repoName}:latest"
                        def imageTagBuild = "${ecrRegistry}/${repoName}:${env.BUILD_NUMBER}"

                        sh "docker build -f docker/Dockerfile \
                            --build-arg ARTIFACT_NAME=${fullModuleName}/target/${fullModuleName}-4.0.1 \
                            --build-arg EXPOSED_PORT=${port} \
                            -t ${imageTagLatest} \
                            -t ${imageTagBuild} \
                            ."
                        
                        echo "📤 Pushing ${repoName} to ECR..."
                        sh "docker push ${imageTagLatest}"
                        sh "docker push ${imageTagBuild}"
                    }
                }
            }
        }

        stage('🔍 Security Scan (Trivy)') {
            steps {
                script {
                    // Resolve ECR Registry dynamically
                    def ecrRegistry = params.ECR_REGISTRY
                    if (!ecrRegistry) {
                        def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                        ecrRegistry = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    }

                    def services = ['config-server', 'discovery-server', 'customers-service', 'vets-service', 'visits-service', 'api-gateway', 'admin-server']
                    
                    // Use the larger data disk for Trivy cache AND temporary downloads
                    def trivyBaseDir = "/mnt/data/trivy"
                    def trivyCacheDir = "${trivyBaseDir}/cache"
                    def trivyTmpDir = "${trivyBaseDir}/tmp"
                    
                    sh "mkdir -p ${trivyCacheDir} ${trivyTmpDir}"

                    services.each { serviceShortName ->
                        def repoName = "petclinic-dev-${serviceShortName}"
                        def fullImageName = "${ecrRegistry}/${repoName}:latest"
                        
                        echo "🛡️ Scanning image: ${fullImageName}..."
                        // Set TMPDIR to specify where Trivy downloads and extracts temporary files
                        sh """
                            export TMPDIR=${trivyTmpDir}
                            trivy image --severity HIGH,CRITICAL --no-progress --exit-code 0 --cache-dir ${trivyCacheDir} ${fullImageName}
                        """
                    }
                    // Optional: Cleanup tmp files after scan to keep disk clean
                    sh "rm -rf ${trivyTmpDir}/*"
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
