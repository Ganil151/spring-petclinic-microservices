# ArgoCD Usage Guide for Spring Petclinic

This guide explains how to use ArgoCD to manage the Spring Petclinic Microservices deployment.

## 1. Accessing ArgoCD

### Get the URL
To access the ArgoCD Web UI:

```bash
# Get the NodePort
NODE_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')

# Method 1: Get IP from Kubernetes (if ExternalIP is set)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# Method 2: If Method 1 is empty, use your Master Node's Public IP (check AWS Console or inventory.ini)
# Example: 
# NODE_IP="13.222.201.118"

if [ -z "$NODE_IP" ]; then
    echo "ExternalIP not found in K8s node status. Please replace <PUBLIC_IP> with your EC2 Public IP."
    echo "https://<PUBLIC_IP>:${NODE_PORT}"
else
    echo "https://${NODE_IP}:${NODE_PORT}"
fi
```

### Get the Password
The default username is `admin`. To retrieve the password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

---

## 2. Managing Deployments

### The Dashboard
Once logged in, you will see "Applications" tiles (e.g., `spring-petclinic-dev`, `spring-petclinic-staging`).

-   **Heart Icon**: Represents Health Status. Green is Healthy. Red/Broken Heart is Degraded.
-   **Sync Icon**: Represents Git Sync Status. Green is Synced. Yellow is OutOfSync.

### Triggering a Deployment (Sync)
When you push changes to Git, ArgoCD will detect them (usually within 3 minutes). To deploy immediately:

1.  Click the application tile (e.g., `spring-petclinic-dev`).
2.  Click the **Sync** button in the top toolbar.
3.  Click **Synchronize** in the slide-out panel.

ArgoCD will modify the Kubernetes resources to match your Git commit.

### Rolling Back
If a deployment breaks:

1.  Click the **History and Rollback** button in the top toolbar.
2.  Find the last known good revision (green checkmark).
3.  Click the three dots `...` and select **Rollback**.

This will revert the cluster state to that specific Git commit.

---

## 3. Investigating Issues

### Viewing Logs
If a pod is failing (Red):

1.  Click on the Application.
2.  Switch to the **Network** or **Tree** view.
3.  Find the failing Pod (red circle).
4.  Click the Pod and select the **Logs** tab at the top.
5.  You can view live stdout/stderr logs here.

### Checking Events
To see why a pod isn't starting (e.g., `CrashLoopBackOff`, `ImagePullBackOff`):

1.  Click the failing Pod.
2.  Select the **Events** tab.
3.  Look for `Warning` events (e.g., "Failed to pull image", "Readiness probe failed").

---

## 4. Troubleshooting Common Error

### "Context Deadline Exceeded" (CrashLoop)
If the **Repo Server** keeps restarting, the cluster might be overloaded.

**Fix:** Run the provided fix script:
```bash
./scripts/fix_argocd.sh
```

### "OutOfSync" Warning
This means someone modified the cluster directly (e.g., using `kubectl edit`). ArgoCD detects this drift.

**Fix:** Click **Sync** to overwrite the manual changes and enforce the Git state.

### "Infinite Syncing"
If an app stays in "Syncing" state forever:
1.  Check the logs of the `argocd-application-controller` pod.
2.  Ensure your Git repository is accessible.
