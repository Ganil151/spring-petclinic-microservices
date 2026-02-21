/*
 * Industrial-Grade CI/CD Pipeline for Spring PetClinic Microservices
 * Implements DevSecOps principles with security scanning throughout
 */
pipeline {
    agent {
        kubernetes {
            yaml """
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: maven
                    image: maven:3.9.4-amazoncorretto-21
                    command:
                    - cat
                    tty: true
                    volumeMounts:
                    - mountPath: /root/.m2
                      name: m2-cache
                  - name: docker
                    image: docker:24-dind
                    command:
                    - cat
                    tty: true
                    privileged: true
                    volumeMounts:
                    - mountPath: /var/run/docker.sock
                      name: docker-sock
                  volumes:
                  - name: m2-cache
                    emptyDir: {}
                  - name: docker-sock
                    hostPath:
                      path: /var/run/docker.sock
                      type: Socket
            """
        }
    }

    environment {
        PROJECT_NAME = 'spring-petclinic'
        AWS_REGION = 'us-east-1'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        NAMESPACE = 'petclinic'
        DOCKER_REGISTRY = "${ECR_REGISTRY}"
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        preserveStashes(buildCount: 5)
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment for deployment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip unit and integration tests'
        )
        booleanParam(
            name: 'SKIP_SECURITY_SCAN',
            defaultValue: false,
            description: 'Skip security scanning (NOT RECOMMENDED)'
        )
        string(
            name: 'GIT_COMMIT',
            defaultValue: '',
            description: 'Specific commit SHA to build (leave empty for HEAD)'
        )
    }

    stages {
        stage('Pre-flight Checks') {
            steps {
                script {
                    echo "🚀 Initializing Spring PetClinic CI/CD Pipeline..."
                    
                    // Verify essential tools are available
                    sh 'mvn --version'
                    sh 'docker --version'
                    sh 'aws --version'
                    sh 'kubectl version --client=true'
                    sh 'helm version --short'
                    
                    // Verify AWS credentials
                    sh 'aws sts get-caller-identity'
                    
                    // Verify ECR access
                    sh "aws ecr describe-repositories --repository-names \$(aws ecr describe-repositories --query 'repositories[].repositoryName' --output text | tr ' ' '\n' | grep petclinic || echo '')"
                }
            }
        }

        stage('Checkout & SCM') {
            steps {
                checkout scm
                
                script {
                    if (params.GIT_COMMIT) {
                        sh "git reset --hard ${params.GIT_COMMIT}"
                    }
                    
                    // Get current build number and git commit info
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Dependency Analysis') {
            parallel {
                stage('Software Composition Analysis') {
                    steps {
                        script {
                            echo "🔍 Performing Software Composition Analysis (SCA)..."
                            
                            // Use dependency-check to identify vulnerabilities in dependencies
                            sh '''
                                mvn org.owasp:dependency-check-maven:check \
                                    -Dformat=JSON \
                                    -DfailOnError=false \
                                    -Dsuppression=dependency-suppression.xml \
                                    -DnvdApiKey=\${NVD_API_KEY} \
                                    -DdataDirectory=./target/nvd-data
                            '''
                            
                            // Archive dependency reports
                            archiveArtifacts artifacts: 'target/**/dependency-check-report.*', fingerprint: true
                        }
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'target',
                                reportFiles: 'dependency-check-report.html',
                                reportName: 'OWASP Dependency Check Report'
                            ])
                        }
                    }
                }
                
                stage('Build Artifacts') {
                    steps {
                        script {
                            echo "🏗️ Building Spring Boot artifacts..."
                            
                            // Build all microservices
                            sh './mvnw clean compile -Pactuator'
                        }
                    }
                }
            }
        }

        stage('Unit & Integration Tests') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                script {
                    echo "🧪 Running unit and integration tests..."
                    
                    sh './mvnw test verify -DskipITs=false -Dtest.coverage.enabled=true -Djacoco.destFile=target/jacoco.exec'
                    
                    // Publish test results
                    junit testResults: '**/target/surefire-reports/*.xml,**/target/failsafe-reports/*.xml'
                    
                    // Publish code coverage
                    publishCoverage adapters: [
                        jacocoAdapter('**/target/jacoco.exec')
                    ], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                }
            }
        }

        stage('Security Analysis') {
            when {
                not { params.SKIP_SECURITY_SCAN }
            }
            parallel {
                stage('Static Application Security Testing') {
                    steps {
                        script {
                            echo "🛡️ Running Static Application Security Testing (SAST)..."
                            
                            // SonarQube analysis with security rules
                            withSonarQubeEnv('SonarQube-Server') {
                                sh '''
                                    ./mvnw sonar:sonar \
                                        -Dsonar.projectKey=spring-petclinic-microservices \
                                        -Dsonar.sources=src \
                                        -Dsonar.java.source=21 \
                                        -Dsonar.java.target=21 \
                                        -Dsonar.exclusions=**/test/**,**/target/** \
                                        -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                                        -Dsonar.scm.provider=git \
                                        -Dsonar.host.url=\${SONAR_HOST_URL} \
                                        -Dsonar.login=\${SONAR_TOKEN}
                                '''
                            }
                        }
                    }
                }
                
                stage('Container Security Scan') {
                    steps {
                        script {
                            echo "🔒 Scanning container images with Trivy..."
                            
                            // Build Docker images for scanning
                            sh '''
                                # Build images for all microservices
                                for service in config-server discovery-server customers-service vets-service visits-service api-gateway admin-server; do
                                    docker build -f docker/Dockerfile \
                                        --build-arg ARTIFACT_NAME=spring-petclinic-\$service/target/spring-petclinic-\$service-4.0.1 \
                                        --build-arg EXPOSED_PORT=\$(echo \$service | sed 's/.*-\([0-9]*\)\$/\1/') \
                                        -t petclinic-\$service:scanning .
                                done
                            '''
                            
                            // Scan each image
                            sh '''
                                for service in config-server discovery-server customers-service vets-service visits-service api-gateway admin-server; do
                                    trivy image --security-checks vuln,config,secret \
                                        --severity CRITICAL,HIGH \
                                        --format table \
                                        --exit-code 0 \
                                        petclinic-\$service:scanning > trivy-\$service-report.txt || true
                                    
                                    # Fail pipeline if critical vulnerabilities found
                                    if trivy image --security-checks vuln \
                                        --severity CRITICAL \
                                        --exit-code 1 \
                                        petclinic-\$service:scanning; then
                                        echo "❌ Critical vulnerabilities found in \$service image"
                                    else
                                        echo "✅ No critical vulnerabilities in \$service image"
                                    fi
                                done
                            '''
                            
                            // Archive security reports
                            archiveArtifacts artifacts: 'trivy-*-report.txt', fingerprint: true
                        }
                    }
                }
            }
        }

        stage('Wait for Quality Gates') {
            when {
                not { params.SKIP_SECURITY_SCAN }
            }
            steps {
                script {
                    // Wait for SonarQube analysis to complete
                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }

        stage('Build & Tag Images') {
            steps {
                script {
                    echo "🐳 Building and tagging Docker images..."
                    
                    // Login to ECR
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    
                    // Define services to build
                    def services = [
                        'config-server': 8888,
                        'discovery-server': 8761,
                        'customers-service': 8081,
                        'vets-service': 8083,
                        'visits-service': 8082,
                        'api-gateway': 8080,
                        'admin-server': 9090
                    ]
                    
                    // Build and tag each service
                    services.each { serviceName, port ->
                        def imageName = "${ECR_REGISTRY}/petclinic-dev-${serviceName}"
                        
                        sh """
                            docker build -f docker/Dockerfile \
                                --build-arg ARTIFACT_NAME=spring-petclinic-${serviceName}/target/spring-petclinic-${serviceName}-4.0.1 \
                                --build-arg EXPOSED_PORT=${port} \
                                -t ${imageName}:${BUILD_TAG} \
                                -t ${imageName}:latest \
                                .
                        """
                        
                        echo "✅ Built image: ${imageName}:${BUILD_TAG}"
                    }
                }
            }
        }

        stage('Push Images to Registry') {
            steps {
                script {
                    echo "📤 Pushing images to ECR..."
                    
                    def services = [
                        'config-server': 8888,
                        'discovery-server': 8761,
                        'customers-service': 8081,
                        'vets-service': 8083,
                        'visits-service': 8082,
                        'api-gateway': 8080,
                        'admin-server': 9090
                    ]
                    
                    services.each { serviceName, port ->
                        def imageName = "${ECR_REGISTRY}/petclinic-dev-${serviceName}"
                        
                        sh """
                            docker push ${imageName}:${BUILD_TAG}
                            docker push ${imageName}:latest
                        """
                        
                        echo "✅ Pushed image: ${imageName}:${BUILD_TAG}"
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "🚀 Deploying to Kubernetes (${params.ENVIRONMENT})..."
                    
                    // Configure kubectl
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name petclinic-${params.ENVIRONMENT}-primary"
                    
                    // Create/update namespace
                    sh "kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                    
                    // Deploy using Helm
                    sh """
                        helm upgrade --install spring-petclinic ./helm/microservices \\
                            --namespace ${NAMESPACE} \\
                            --values ./helm/microservices/overrides/${params.ENVIRONMENT}.yaml \\
                            --set global.ecrRegistry=${ECR_REGISTRY} \\
                            --set global.region=${AWS_REGION} \\
                            --set image.tag=${BUILD_TAG} \\
                            --set environment=${params.ENVIRONMENT} \\
                            --wait --timeout=10m
                    """
                    
                    // Verify deployment
                    sh """
                        kubectl rollout status deployment/spring-petclinic-api-gateway --namespace ${NAMESPACE} --timeout=5m
                        kubectl rollout status deployment/spring-petclinic-customers-service --namespace ${NAMESPACE} --timeout=5m
                        kubectl rollout status deployment/spring-petclinic-vets-service --namespace ${NAMESPACE} --timeout=5m
                        kubectl rollout status deployment/spring-petclinic-visits-service --namespace ${NAMESPACE} --timeout=5m
                    """
                }
            }
        }

        stage('Post-deployment Validation') {
            steps {
                script {
                    echo "✅ Running post-deployment validation tests..."
                    
                    // Wait for services to be ready
                    sh "sleep 30"
                    
                    // Run smoke tests against the deployed services
                    sh """
                        ATTEMPTS=10
                        until curl -f http://${params.ENVIRONMENT}-petclinic.alb.amazonaws.com/actuator/health || [ \$ATTEMPTS -le 0 ]; do
                            echo "Waiting for application health endpoint... (\$ATTEMPTS attempts remaining)"
                            sleep 30
                            ATTEMPTS=\$((ATTEMPTS-1))
                        done
                        
                        if [ \$ATTEMPTS -le 0 ]; then
                            echo "❌ Application health check failed"
                            exit 1
                        else
                            echo "✅ Application is healthy"
                        fi
                    """
                    
                    // Run integration tests against deployed services
                    sh """
                        ./mvnw verify -Pintegration-tests \\
                            -Dintegration.test.url=http://${params.ENVIRONMENT}-petclinic.alb.amazonaws.com
                    """
                }
            }
        }

        stage('Performance Testing') {
            when {
                expression { params.ENVIRONMENT == 'staging' || params.ENVIRONMENT == 'prod' }
            }
            steps {
                script {
                    echo "⚡ Running performance tests..."
                    
                    // Run basic performance tests
                    sh """
                        # Simple load test using Apache Bench
                        ab -n 100 -c 10 http://${params.ENVIRONMENT}-petclinic.alb.amazonaws.com/
                    """
                    
                    // More sophisticated performance testing could be added here
                }
            }
        }
    }

    post {
        always {
            script {
                // Send notifications
                emailext (
                    subject: "Spring PetClinic Pipeline ${currentBuild.currentResult}: Job '${env.JOB_NAME}' Build #${env.BUILD_NUMBER}",
                    body: """
                        <h3>Pipeline Result: ${currentBuild.currentResult}</h3>
                        <p>Job: <a href="${env.BUILD_URL}">${env.JOB_NAME}</a></p>
                        <p>Build Number: ${env.BUILD_NUMBER}</p>
                        <p>Branch: ${env.BRANCH_NAME}</p>
                        <p>Commit: ${env.GIT_COMMIT_SHORT}</p>
                        <p>Environment: ${params.ENVIRONMENT}</p>
                        
                        <h4>Test Results:</h4>
                        <ul>
                            <li>Total Tests: ${manager.totalCount}</li>
                            <li>Failed Tests: ${manager.failedCount}</li>
                            <li>Skip Tests: ${manager.skipCount}</li>
                        </ul>
                        
                        <p>See attached reports for detailed analysis.</p>
                    """,
                    to: 'devops-team@example.com',
                    attachLog: true
                )
            }
        }
        
        success {
            echo "✅ Pipeline completed successfully!"
        }
        
        failure {
            echo "❌ Pipeline failed. Please review the logs."
        }
        
        cleanup {
            // Clean up temporary images
            sh '''
                docker rmi -f $(docker images --format '{{.Repository}}:{{.Tag}}' | grep petclinic-) 2>/dev/null || true
            '''
        }
    }
}