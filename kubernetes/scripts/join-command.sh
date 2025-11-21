# 1. SSH into K8s-Master-Server
ssh -i your-key.pem ec2-user@<MASTER_PUBLIC_IP>

# 2. Get the join command
cat /tmp/k8s_join_command.sh
# OR generate a new one:
kubeadm token create --print-join-command

# 3. Copy the output (it will look like):
# sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>

# 4. SSH into K8s-Worker-Server
ssh -i your-key.pem ec2-user@<WORKER_PUBLIC_IP>

# 5. Run the join command on the worker
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>

# 6. Verify on the master
# Back on the master node:
kubectl get nodes