# Webhook Implementation - Quick Reference

## 🚀 Quick Start (5 Steps)

### 1. Deploy Infrastructure
```bash
cd terraform/app
terraform apply
# Note the webhook server IP
```

### 2. Configure Kubernetes RBAC
```bash
kubectl apply -f kubernetes/webhook-rbac.yaml
```

### 3. Generate and Copy Kubeconfig
```bash
# On K8s Master:
cd scripts
./generate-kubeconfig.sh
scp webhook-kubeconfig ec2-user@<WEBHOOK-IP>:/tmp/

# On Webhook Server:
sudo mv /tmp/webhook-kubeconfig /root/.kube/config
sudo chmod 600 /root/.kube/config
sudo systemctl start webhook-receiver
```

### 4. Configure Docker Hub
For each repository (ganil151/customers-service, etc.):
- Go to Docker Hub → Repository → Webhooks
- URL: `http://<WEBHOOK-IP>:9000/webhook`
- Name: `k8s-deployment-trigger`

### 5. Test
```bash
./scripts/test-webhook.sh <WEBHOOK-IP>
```

---

## 📁 Files Created

| File | Purpose |
|------|---------|
| `kubernetes/webhook-rbac.yaml` | RBAC configuration |
| `scripts/generate-kubeconfig.sh` | Kubeconfig generator |
| `scripts/test-webhook.sh` | Testing utility |
| `scripts/configure-dockerhub-webhooks.sh` | Docker Hub helper |
| `terraform/app/scripts/webhook_receiver.sh` | Server setup script |
| `docs/WEBHOOK_IMPLEMENTATION_GUIDE.md` | Full documentation |

---

## 🔍 Common Commands

### Check Webhook Service
```bash
ssh ec2-user@<WEBHOOK-IP>
sudo systemctl status webhook-receiver
sudo tail -f /var/log/webhook-receiver/webhook.log
```

### Test Health
```bash
curl http://<WEBHOOK-IP>:9000/health
```

### Verify kubectl
```bash
ssh ec2-user@<WEBHOOK-IP>
sudo kubectl get nodes
sudo kubectl get deployments
```

### Watch Deployments
```bash
kubectl get pods -w
```

---

## 🎯 Configured Microservices

The webhook server is pre-configured for:
- ✅ api-gateway
- ✅ customers-service
- ✅ vets-service
- ✅ visits-service
- ✅ admin-server
- ✅ config-server
- ✅ discovery-server

---

## 🔧 Troubleshooting

### Service won't start
```bash
sudo journalctl -u webhook-receiver -n 50
```

### kubectl not working
```bash
sudo ls -la /root/.kube/config
sudo kubectl get nodes
```

### Webhook not triggering
- Check Docker Hub webhook delivery logs
- Verify security group allows port 9000
- Check webhook server logs

---

## 📚 Full Documentation

See `docs/WEBHOOK_IMPLEMENTATION_GUIDE.md` for:
- Detailed step-by-step instructions
- Architecture diagrams
- Security hardening
- Production best practices
- Complete troubleshooting guide

---

## 🔐 Security Notes

**Current Setup**: Development (port 9000 open to all)

**Production Recommendations**:
1. Restrict port 9000 to Docker Hub IPs only
2. Enable HTTPS with nginx reverse proxy
3. Configure webhook secret validation
4. Enable firewall rules

See implementation guide for details.
