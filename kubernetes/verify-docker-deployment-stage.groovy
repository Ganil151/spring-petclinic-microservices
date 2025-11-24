stage('Verify Docker Deployment') {
    when {
        expression { params.DEPLOYMENT_TARGET in ['docker', 'both'] }
    }
    steps {
        withCredentials([
            [$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']
        ]) {
            script {
                echo "Verifying Docker deployment on Docker-Server..."
                
                sh '''
                set -e
                REMOTE_IP=$(cat public_ip.txt)
                SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                
                echo "=== Checking Docker containers status ==="
                ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'"
                
                echo ""
                echo "=== Waiting for services to start (30 seconds) ==="
                sleep 30
                
                echo ""
                echo "=== Verifying service health endpoints ==="
                
                # Check config-server
                echo "Checking config-server..."
                ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8888/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                    echo "ERROR: config-server health check failed"
                    exit 1
                }
                echo "✓ config-server is UP"
                
                # Check discovery-server
                echo "Checking discovery-server..."
                ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8761/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                    echo "ERROR: discovery-server health check failed"
                    exit 1
                }
                echo "✓ discovery-server is UP"
                
                # Check api-gateway
                echo "Checking api-gateway..."
                ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8080/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                    echo "ERROR: api-gateway health check failed"
                    exit 1
                }
                echo "✓ api-gateway is UP"
                
                # Check customers-service
                echo "Checking customers-service..."
                ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8081/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                    echo "WARNING: customers-service health check failed (may still be starting)"
                }
                echo "✓ customers-service checked"
                
                # Check visits-service
                echo "Checking visits-service..."
                ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8082/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                    echo "WARNING: visits-service health check failed (may still be starting)"
                }
                echo "✓ visits-service checked"
                
                # Check vets-service
                echo "Checking vets-service..."
                ssh ${SSH_OPTS} ${SSH_USER}@${REMOTE_IP} "curl -f -s http://localhost:8083/actuator/health | jq -r '.status' || echo 'FAILED'" | grep -q "UP" || {
                    echo "WARNING: vets-service health check failed (may still be starting)"
                }
                echo "✓ vets-service checked"
                
                echo ""
                echo "=== Docker Deployment Verification Complete ==="
                echo "✓ All critical services (config, discovery, api-gateway) are healthy"
                '''
            }
        }
    }
}
