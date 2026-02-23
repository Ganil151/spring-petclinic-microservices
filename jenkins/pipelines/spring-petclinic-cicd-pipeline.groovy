pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3-eclipse-temurin-17
    command: ['cat']
    tty: true
  - name: docker
    image: docker:latest
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['cat']
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }

    environment {
        AWS_REGION = "us-east-1"
        ECR_REGISTRY = "637423548943.dkr.ecr.us-east-1.amazonaws.com" // Placeholder - will be dynamic in full CI
        SONAR_URL = "http://sonarqube-server:9000"
        PROJECT_NAME = "spring-petclinic"
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "Starting CI/CD for ${PROJECT_NAME}..."
                }
            }
        }

        stage('Build Microservices') {
            parallel {
                stage('Customers Service') {
                    steps {
                        container('maven') {
                            dir('spring-petclinic-customers-service') {
                                sh 'mvn clean package -DskipTests'
                            }
                        }
                    }
                }
                stage('Vets Service') {
                    steps {
                        container('maven') {
                            dir('spring-petclinic-vets-service') {
                                sh 'mvn clean package -DskipTests'
                            }
                        }
                    }
                }
                stage('Visits Service') {
                    steps {
                        container('maven') {
                            dir('spring-petclinic-visits-service') {
                                sh 'mvn clean package -DskipTests'
                            }
                        }
                    }
                }
            }
        }

        stage('SonarQube Static Analysis') {
            steps {
                container('maven') {
                    script {
                        // In a real scenario, use withSonarQubeEnv('SonarQube-Server') {}
                        echo "Running SonarQube Scan..."
                        // sh 'mvn sonar:sonar -Dsonar.host.url=${SONAR_URL}'
                    }
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                container('docker') {
                    script {
                        echo "Building Docker Images..."
                        // Simplified loop for demonstration
                        def services = ['customers-service', 'vets-service', 'visits-service', 'api-gateway']
                        services.each { service ->
                            sh "docker build -t ${ECR_REGISTRY}/${PROJECT_NAME}-${service}:latest ./spring-petclinic-${service}"
                            // sh "docker push ${ECR_REGISTRY}/${PROJECT_NAME}-${service}:latest"
                        }
                    }
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                container('kubectl') {
                    script {
                        echo "Deploying to EKS via Kustomize..."
                        sh "kubectl apply -k k8s/overlays/dev"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
        }
        success {
            echo "Deployment successful!"
        }
        failure {
            echo "Deployment failed. Check logs."
        }
    }
}
