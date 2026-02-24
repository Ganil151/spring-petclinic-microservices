// =============================================================================
// Spring Petclinic Root Jenkinsfile
// 🧪 Industrial Rigor: This is a Declarative Entry Point that leverages 
// modular logic stored in the /jenkins directory.
// =============================================================================

pipeline {
    agent { label 'jenkins-agent' } // Defined in jenkins.yaml JCasC

    environment {
        PROJECT_NAME = "spring-petclinic"
        AWS_REGION   = "us-east-1"
        SONAR_URL    = "http://sonarqube-server:9000"
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "Initializing Pipeline for ${PROJECT_NAME}..."
                    // Load helper scripts from the /jenkins folder
                    utils = load "jenkins/pipelines/spring-petclinic-cicd-pipeline.groovy"
                }
            }
        }

        stage('Security & Audit') {
            when { expression { params.RUN_SECURITY_SCAN != null ? params.RUN_SECURITY_SCAN : true } }
            steps {
                script {
                    echo "Referencing Security Pipeline from /jenkins folder..."
                    def securityScan = load "jenkins/pipelines/security-scan-pipeline.groovy"
                    securityScan.call()
                }
            }
        }

        stage('Build & Package') {
            steps {
                container('maven') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Containerize & Deploy') {
            steps {
                script {
                    echo "Referencing Deployment Pipeline from /jenkins folder..."
                    def deployment = load "jenkins/pipelines/deployment-pipeline.groovy"
                    deployment.call()
                }
            }
        }
    }

    post {
        always {
            echo "CI/CD Cycle Complete."
        }
    }
}
