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
        string(name: 'GITHUB_CREDENTIALS_ID', defaultValue: 'github-credentials', description: 'github-credentials')
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: params.GITHUB_CREDENTIALS_ID, url: 'https://github.com/Ganil151/spring-petclinic-microservices.git'
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
