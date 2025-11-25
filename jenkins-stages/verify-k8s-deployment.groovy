stage('Verify Kubernetes Deployment') {
    steps {
        script {
            echo "Verifying Kubernetes deployment..."
            
            sh '''
            set -e
            
            echo "=== Kubernetes Deployment Verification ==="
            echo ""
            
            # Verify kubectl is configured
            echo "=== Checking kubectl Configuration ==="
            if ! kubectl cluster-info &>/dev/null; then
                echo "ERROR: kubectl is not configured or cannot connect to cluster"
                exit 1
            fi
            echo "✓ kubectl is configured and connected"
            echo ""
            
            # Check cluster nodes
            echo "=== Cluster Nodes Status ==="
            kubectl get nodes
            echo ""
            
            # Verify all nodes are Ready
            NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
            if [ "$NOT_READY" -gt 0 ]; then
                echo "WARNING: $NOT_READY node(s) are not in Ready state"
                kubectl get nodes
            else
                echo "✓ All nodes are Ready"
            fi
            echo ""
            
            # Check deployments status
            echo "=== Deployment Status ==="
            kubectl get deployments -o wide
            echo ""
            
            # Check if all deployments are available
            echo "=== Checking Deployment Availability ==="
            DEPLOYMENTS=$(kubectl get deployments -o jsonpath='{.items[*].metadata.name}')
            
            for deployment in $DEPLOYMENTS; do
                READY=$(kubectl get deployment $deployment -o jsonpath='{.status.readyReplicas}')
                DESIRED=$(kubectl get deployment $deployment -o jsonpath='{.spec.replicas}')
                
                if [ "$READY" = "$DESIRED" ] && [ "$READY" != "" ]; then
                    echo "✓ $deployment: $READY/$DESIRED replicas ready"
                else
                    echo "⚠ $deployment: $READY/$DESIRED replicas ready (not fully available)"
                fi
            done
            echo ""
            
            # Check pods status
            echo "=== Pod Status ==="
            kubectl get pods -o wide
            echo ""
            
            # Check for pods not in Running state
            echo "=== Checking Pod Health ==="
            NOT_RUNNING=$(kubectl get pods --no-headers | grep -v "Running" | grep -v "Completed" | wc -l)
            if [ "$NOT_RUNNING" -gt 0 ]; then
                echo "WARNING: $NOT_RUNNING pod(s) are not in Running state"
                kubectl get pods | grep -v "Running" | grep -v "Completed" | grep -v "NAME" || true
                echo ""
                echo "=== Pod Details for Non-Running Pods ==="
                kubectl get pods --no-headers | grep -v "Running" | grep -v "Completed" | awk '{print $1}' | while read pod; do
                    echo "--- Pod: $pod ---"
                    kubectl describe pod $pod | tail -20
                    echo ""
                done
            else
                echo "✓ All pods are in Running or Completed state"
            fi
            echo ""
            
            # Check services
            echo "=== Service Status ==="
            kubectl get services -o wide
            echo ""
            
            # Check for infrastructure services
            echo "=== Verifying Infrastructure Services ==="
            INFRA_SERVICES="config-server discovery-server"
            for service in $INFRA_SERVICES; do
                if kubectl get deployment $service &>/dev/null; then
                    READY=$(kubectl get deployment $service -o jsonpath='{.status.readyReplicas}')
                    if [ "$READY" -gt 0 ]; then
                        echo "✓ $service is running ($READY replicas)"
                    else
                        echo "⚠ $service is not ready"
                    fi
                else
                    echo "⚠ $service deployment not found"
                fi
            done
            echo ""
            
            # Check for microservices
            echo "=== Verifying Microservices ==="
            MICROSERVICES="customers-service visits-service vets-service api-gateway"
            for service in $MICROSERVICES; do
                if kubectl get deployment $service &>/dev/null; then
                    READY=$(kubectl get deployment $service -o jsonpath='{.status.readyReplicas}')
                    if [ "$READY" -gt 0 ]; then
                        echo "✓ $service is running ($READY replicas)"
                    else
                        echo "⚠ $service is not ready"
                    fi
                else
                    echo "⚠ $service deployment not found"
                fi
            done
            echo ""
            
            # Get API Gateway access information
            echo "=== API Gateway Access Information ==="
            if kubectl get service api-gateway &>/dev/null; then
                SERVICE_TYPE=$(kubectl get service api-gateway -o jsonpath='{.spec.type}')
                echo "Service Type: $SERVICE_TYPE"
                
                if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
                    LB_HOSTNAME=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                    LB_IP=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                    if [ -n "$LB_HOSTNAME" ]; then
                        echo "LoadBalancer URL: http://$LB_HOSTNAME"
                    elif [ -n "$LB_IP" ]; then
                        echo "LoadBalancer URL: http://$LB_IP"
                    else
                        echo "LoadBalancer is being provisioned..."
                    fi
                elif [ "$SERVICE_TYPE" = "NodePort" ]; then
                    NODE_PORT=$(kubectl get service api-gateway -o jsonpath='{.spec.ports[0].nodePort}')
                    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
                    if [ -z "$NODE_IP" ]; then
                        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
                    fi
                    echo "NodePort URL: http://$NODE_IP:$NODE_PORT"
                    echo ""
                    echo "You can access the application at: http://$NODE_IP:$NODE_PORT"
                fi
            else
                echo "⚠ api-gateway service not found"
            fi
            echo ""
            
            # Check for any recent events (errors/warnings)
            echo "=== Recent Cluster Events (Last 10) ==="
            kubectl get events --sort-by='.lastTimestamp' | tail -10
            echo ""
            
            # Summary
            echo "=== Verification Summary ==="
            TOTAL_PODS=$(kubectl get pods --no-headers | wc -l)
            RUNNING_PODS=$(kubectl get pods --no-headers | grep "Running" | wc -l)
            TOTAL_DEPLOYMENTS=$(kubectl get deployments --no-headers | wc -l)
            
            echo "Total Deployments: $TOTAL_DEPLOYMENTS"
            echo "Total Pods: $TOTAL_PODS"
            echo "Running Pods: $RUNNING_PODS"
            echo ""
            
            if [ "$NOT_RUNNING" -eq 0 ]; then
                echo "✓ Kubernetes Deployment Verification Complete - All systems healthy"
            else
                echo "⚠ Kubernetes Deployment Verification Complete - Some issues detected"
                echo "Please review the warnings above"
            fi
            '''
        }
    }
}
