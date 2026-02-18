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
