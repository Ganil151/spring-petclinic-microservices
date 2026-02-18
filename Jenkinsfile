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
