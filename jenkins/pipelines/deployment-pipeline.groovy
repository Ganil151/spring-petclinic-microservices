// Modular Deployment Script
// Called by the root Jenkinsfile stage('Containerize & Deploy')

container('docker') {
    echo "🐳 Building Docker Images for Microservices..."
    sh "docker build -t spring-petclinic-api-gateway:latest ./spring-petclinic-api-gateway"
    // sh "docker push ... "
}

container('kubectl') {
    echo "🚢 Deploying to EKS Cluster..."
    sh "kubectl apply -k k8s/overlays/dev"
}
