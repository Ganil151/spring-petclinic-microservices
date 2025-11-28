# ArgoCD Setup Guide for Spring Petclinic Microservices

## What is ArgoCD?

ArgoCD is a **declarative GitOps continuous delivery tool** for Kubernetes. It:
- Automatically syncs your cluster state with Git repository
- Provides a visual dashboard to monitor deployments
- Enables automated rollbacks and health monitoring
- Implements GitOps best practices

## Benefits for Your Project

- **Single Source of Truth**: Git becomes the source of truth for cluster state
- **Automated Deployments**: Push to Git → ArgoCD automatically deploys
- **Visibility**: Web UI shows deployment status and health
- **Rollback**: Easy rollback to any previous Git commit
- **Multi-Environment**: Manage dev, staging, prod from one place

---

## Installation Steps

### Step 1: Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 2: Expose ArgoCD Server

**Option A: NodePort (for testing/development)**
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "nodePort": 30443, "name": "https"}]}}'
```

**Option B: Port Forward (local access)**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at: https://localhost:8080
```

**Option C: LoadBalancer (for AWS/cloud)**
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

### Step 3: Get Initial Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Username: admin
# Password: (output from above command)
```

### Step 4: Install ArgoCD CLI (Optional but Recommended)

**Linux:**
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

**Windows (Git Bash/WSL):**
```bash
curl -sSL -o argocd-windows-amd64.exe https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe
# Move to a directory in your PATH
```

**Mac:**
```bash
brew install argocd
```

### Step 5: Login via CLI

```bash
# Get the ArgoCD server address
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Or for NodePort
ARGOCD_SERVER="<your-node-ip>:30443"

# Login
argocd login $ARGOCD_SERVER --insecure
# Username: admin
# Password: (from Step 3)

# Change password
argocd account update-password
```

---

## Configuring ArgoCD for Spring Petclinic

### Step 6: Create ArgoCD Application

You have two options:

#### Option A: Create Application via UI
1. Open ArgoCD UI (https://<node-ip>:30443)
2. Click "New App"
3. Fill in:
   - **Application Name**: `spring-petclinic`
   - **Project**: `default`
   - **Sync Policy**: `Automatic` (with Auto-Create Namespace)
   - **Repository URL**: Your Git repo URL
   - **Path**: `kubernetes/deployments`
   - **Cluster**: `https://kubernetes.default.svc`
   - **Namespace**: `default`

#### Option B: Create Application via YAML

See `argocd-application.yaml` in this directory.

```bash
kubectl apply -f kubernetes/argocd/argocd-application.yaml
```

---

## GitOps Workflow

### How It Works

```
Developer → Git Push → ArgoCD detects change → Auto-sync to K8s
```

### Workflow Steps

1. **Make changes** to your deployment YAML files
2. **Commit and push** to Git repository
3. **ArgoCD automatically detects** the changes (every 3 minutes by default)
4. **ArgoCD syncs** the changes to your cluster
5. **Monitor** the deployment in ArgoCD UI

### Manual Sync (if auto-sync is disabled)

```bash
# Sync via CLI
argocd app sync spring-petclinic

# Or click "Sync" in the UI
```

---

## Multi-Environment Setup

### Recommended Structure

```
kubernetes/
├── base/                    # Base configurations
│   ├── deployments/
│   └── services/
├── overlays/
│   ├── dev/                # Development environment
│   │   └── kustomization.yaml
│   ├── staging/            # Staging environment
│   │   └── kustomization.yaml
│   └── prod/               # Production environment
│       └── kustomization.yaml
└── argocd/
    ├── dev-application.yaml
    ├── staging-application.yaml
    └── prod-application.yaml
```

### Create Separate ArgoCD Apps per Environment

```bash
# Dev
argocd app create petclinic-dev \
  --repo https://github.com/your-repo/spring-petclinic-microservices \
  --path kubernetes/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev

# Staging
argocd app create petclinic-staging \
  --repo https://github.com/your-repo/spring-petclinic-microservices \
  --path kubernetes/overlays/staging \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace staging

# Prod
argocd app create petclinic-prod \
  --repo https://github.com/your-repo/spring-petclinic-microservices \
  --path kubernetes/overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod
```

---

## Useful ArgoCD Commands

```bash
# List all applications
argocd app list

# Get application details
argocd app get spring-petclinic

# Sync application
argocd app sync spring-petclinic

# Get application history
argocd app history spring-petclinic

# Rollback to previous version
argocd app rollback spring-petclinic <revision-number>

# Delete application (keeps resources)
argocd app delete spring-petclinic

# Delete application and resources
argocd app delete spring-petclinic --cascade
```

---

## Monitoring and Alerts

### Health Status
- **Healthy**: All resources are healthy
- **Progressing**: Deployment in progress
- **Degraded**: Some resources are unhealthy
- **Suspended**: Application is suspended

### Sync Status
- **Synced**: Git matches cluster state
- **OutOfSync**: Git differs from cluster
- **Unknown**: Cannot determine sync status

### Set Up Notifications (Optional)

Configure Slack/Email notifications for deployment events:
```bash
kubectl apply -f kubernetes/argocd/argocd-notifications.yaml
```

---

## Best Practices

1. **Use Auto-Sync with Caution**: Enable for dev/staging, manual for production
2. **Enable Pruning**: Auto-remove resources deleted from Git
3. **Use Sync Waves**: Control deployment order with annotations
4. **Implement RBAC**: Control who can sync/rollback applications
5. **Monitor Health**: Set up alerts for degraded applications
6. **Use Kustomize/Helm**: For environment-specific configurations

---

## Integration with Jenkins

You can integrate ArgoCD with your existing Jenkins pipeline:

```groovy
stage('Deploy to ArgoCD') {
    steps {
        script {
            sh """
                argocd app sync spring-petclinic --force
                argocd app wait spring-petclinic --health
            """
        }
    }
}
```

This allows Jenkins to:
1. Build and push Docker images
2. Update Kubernetes manifests in Git
3. Trigger ArgoCD sync
4. Wait for deployment to be healthy

---

## Troubleshooting

### Application Won't Sync
```bash
# Check application status
argocd app get spring-petclinic

# View detailed logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync
argocd app sync spring-petclinic --force
```

### Can't Access UI
```bash
# Check if ArgoCD server is running
kubectl get pods -n argocd

# Check service
kubectl get svc -n argocd

# Port forward as fallback
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Authentication Issues
```bash
# Reset admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "", "admin.passwordMtime": ""}}'

# Get new password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Next Steps

1. ✅ Install ArgoCD on your cluster
2. ✅ Configure Git repository
3. ✅ Create ArgoCD application
4. ✅ Test GitOps workflow
5. ✅ Set up multi-environment (optional)
6. ✅ Configure notifications (optional)
7. ✅ Integrate with Jenkins (optional)

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [ArgoCD Examples](https://github.com/argoproj/argocd-example-apps)
