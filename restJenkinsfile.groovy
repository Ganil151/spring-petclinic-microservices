tage('Configure MySQL Database') {
            when {
                expression { return params.CONFIGURE_MYSQL }
            }
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'mysql-root-credentials', 
                                usernameVariable: 'MYSQL_ROOT_USER', 
                                passwordVariable: 'MYSQL_ROOT_PASSWORD'),
                    usernamePassword(credentialsId: 'mysql-petclinic-credentials', 
                                usernameVariable: 'MYSQL_PETCLINIC_USER', 
                                passwordVariable: 'MYSQL_PETCLINIC_PASSWORD')
                ]) {
                    script {
                        echo "Configuring MySQL databases..."
                        
                        dir('ansible') {
                            sh '''
                                set -e
                                
                                echo "=== MySQL Configuration ==="
                                
                                # Test connectivity
                                ansible mysql -i inventory.ini -m ping || {
                                    echo "ERROR: Cannot connect to MySQL server"
                                    exit 1
                                }
                                
                                # Run manual playbook (NOT Galaxy role)
                                ansible-playbook -i inventory.ini mysql_setup.yml -v \
                                    -e "mysql_root_password='${MYSQL_ROOT_PASSWORD}'" \
                                    -e "mysql_petclinic_password='${MYSQL_PETCLINIC_PASSWORD}'"
                                
                                echo "✓ MySQL configuration complete"
                            '''
                        }
                    }
                }
            }
        }

        stage('Setup Kubernetes Master') {
            when {
                expression { 
                    return params.DEPLOYMENT_TARGET == 'kubernetes' || params.DEPLOYMENT_TARGET == 'both' 
                }
            }
            steps {
                script {
                    echo "Setting up Kubernetes master node..."
                    
                    dir('ansible') {
                        sh '''
                            set -e
                            
                            echo "=== Kubernetes Master Setup ==="
                            
                            # Test connectivity to K8s master
                            ansible k8s_master -i inventory.ini -m ping || {
                                echo "ERROR: Cannot connect to K8s master"
                                exit 1
                            }
                            
                            # Run K8s master playbook
                            ansible-playbook -i inventory.ini playbooks/k8s-master.yml -v
                            
                            echo "✓ Kubernetes master setup complete"
                        '''
                    }
                }
            }
        }

        stage('Setup Kubernetes Workers') {
            steps {
                script {
                    echo "Setting up Kubernetes worker nodes..."
                    
                    dir('ansible') {
                        sh '''
                            set -e
                            
                            echo "=== Kubernetes Workers Setup ==="
                            
                            # Test connectivity to K8s workers
                            ansible k8s_primary_workers:k8s_secondary_workers -i inventory.ini -m ping || {
                                echo "ERROR: Cannot connect to K8s workers"
                                exit 1
                            }
                            
                            # Run K8s workers playbook
                            ansible-playbook -i inventory.ini playbooks/k8s-workers.yml -v
                            
                            echo "✓ Kubernetes workers setup complete"
                        '''
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Deploying Spring Petclinic to Kubernetes..."
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP from inventory
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')

                            if [ -z "$K8S_MASTER_IP" ]; then
                                echo "ERROR: Could not find K8s master IP in inventory"
                                exit 1
                            fi
                            
                            echo "K8s Master IP: $K8S_MASTER_IP"
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            
                            echo "=== Copying Kubernetes manifests ==="
                            scp -r ${SSH_OPTS} kubernetes/ ${SSH_USER}@${K8S_MASTER_IP}:~/
                            
                            echo "=== Deploying to Kubernetes ==="
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} bash -s << 'REMOTE_K8S'
                                set -e
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                
                                echo "Verifying cluster status..."
                                kubectl get nodes
                                
                                echo "Applying Kubernetes manifests..."
                                cd ~/kubernetes/base/deployments
                                
                                # Deploy the complete manifest
                                kubectl apply -f deployment.yaml
                                
                                echo "Waiting for pods to be ready..."
                                kubectl wait --for=condition=ready pod -l app=config-server --timeout=300s || true
                                kubectl wait --for=condition=ready pod -l app=discovery-server --timeout=300s || true
                                
                                echo "Cluster status:"
                                kubectl get pods -o wide
                                kubectl get svc
                                
                                echo "✓ Kubernetes deployment complete"
REMOTE_K8S
                        '''
                    }
                }
            }
        }

        stage('Verify Kubernetes Deployment') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Verifying Kubernetes deployment..."
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')
                            
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            
                            echo "=== Kubernetes Cluster Status ==="
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} "
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                echo '--- Nodes ---'
                                kubectl get nodes -o wide
                                echo ''
                                echo '--- Pods ---'
                                kubectl get pods -o wide
                                echo ''
                                echo '--- Services ---'
                                kubectl get svc
                                echo ''
                                echo '--- API Gateway NodePort URL ---'
                                NODE_PORT=\$(kubectl get svc api-gateway -o jsonpath='{.spec.ports[0].nodePort}')
                                NODE_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"ExternalIP\")].address}')
                                if [ -z \"\$NODE_IP\" ]; then
                                    NODE_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}')
                                fi
                                echo \"Access application at: http://\${NODE_IP}:\${NODE_PORT}\"
                            "
                            
                            echo "✓ Kubernetes verification complete"
                        '''
                    }
                }
            }
        }

        stage('Install ArgoCD') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Installing ArgoCD on Kubernetes Master..."
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')
                            
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} bash -s << 'REMOTE'
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                
                                echo "Creating ArgoCD namespace..."
                                kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
                                
                                echo "Installing ArgoCD manifests..."
                                kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
                                
                                echo "Waiting for ArgoCD server components..."
                                # We do not block too long here to avoid timeouts, just fire and forget or short wait
                                kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=60s || echo "ArgoCD still starting up..."
REMOTE
                        '''
                    }
                }
            }
        }

        stage('Deploy to ArgoCD') {
            steps {
                withCredentials([[$class: 'SSHUserPrivateKeyBinding', credentialsId: SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER']]) {
                    script {
                        echo "Registering ArgoCD Application..."
                        
                        sh '''
                            set -e
                            
                            # Get K8s master IP
                            K8S_MASTER_IP=$(grep -A 5 "\\[k8s_master\\]" ansible/inventory.ini | grep "ansible_host" | head -n 1 | awk -F "ansible_host=" '{print $2}' | awk '{print $1}')
                            
                            SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=20 -i ${SSH_KEY}"
                            
                            # We need to copy the ArgoCD app manifest to the master first
                            scp ${SSH_OPTS} kubernetes/argocd/dev-application.yaml ${SSH_USER}@${K8S_MASTER_IP}:~/dev-application.yaml
                            
                            ssh ${SSH_OPTS} ${SSH_USER}@${K8S_MASTER_IP} bash -s << 'REMOTE'
                                export KUBECONFIG=/home/ec2-user/.kube/config
                                
                                echo "Applying ArgoCD Application Manifest..."
                                kubectl apply -f ~/dev-application.yaml
                                
                                echo "Application registered! ArgoCD will now sync the cluster state."
                                echo "Check status with: kubectl get application -n argocd"
REMOTE
                        '''
                    }
                }
            }
        }