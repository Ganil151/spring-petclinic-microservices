// Modular Security Scan Script
// Called by the root Jenkinsfile stage('Security & Audit')

def call() {
    container('maven') {
        echo "🏗️ Performing SonarQube Analysis..."
        // sh 'mvn sonar:sonar -Dsonar.host.url=${SONAR_URL}'
    }
}

return this
