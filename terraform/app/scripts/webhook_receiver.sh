#!/bin/bash
set -e
log(){ echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
log "Starting Webhook Receiver Setup..."
log "Updating system..."
sudo yum update -y
sudo yum install -y python3 python3-pip git
log "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
log "Installing Python deps..."
sudo pip3 install flask requests
sudo mkdir -p /opt/webhook-receiver /var/log/webhook-receiver /root/.kube
sudo chmod 700 /root/.kube
log "Creating webhook app..."
cat<<'A'|sudo tee /opt/webhook-receiver/webhook_server.py>/dev/null
#!/usr/bin/env python3
from flask import Flask,request,jsonify
import subprocess,json,logging,os,hmac,hashlib
from datetime import datetime
logging.basicConfig(level=logging.INFO,format='%(asctime)s-%(levelname)s-%(message)s',handlers=[logging.FileHandler('/var/log/webhook-receiver/webhook.log'),logging.StreamHandler()])
logger=logging.getLogger(__name__)
app=Flask(__name__)
WEBHOOK_SECRET=os.environ.get('WEBHOOK_SECRET','')
REPO_TO_DEPLOYMENT={'ganil151/api-gateway':'api-gateway','ganil151/customers-service':'customers-service','ganil151/vets-service':'vets-service','ganil151/visits-service':'visits-service','ganil151/admin-server':'admin-server','ganil151/config-server':'config-server','ganil151/discovery-server':'discovery-server'}
def validate_signature(p,s):
 if not WEBHOOK_SECRET:logger.warning("No secret");return True
 return hmac.compare_digest(hmac.new(WEBHOOK_SECRET.encode(),p,hashlib.sha256).hexdigest(),s)
def update_deployment(d,i,t):
 try:
  img=f"{i}:{t}";logger.info(f"Updating {d} with {img}")
  r=subprocess.run(['kubectl','set','image',f'deployment/{d}',f'{d}={img}','-n','default'],capture_output=True,text=True,timeout=30)
  if r.returncode!=0:logger.error(f"Failed: {r.stderr}");return False,r.stderr
  logger.info(f"Updated: {r.stdout}")
  rr=subprocess.run(['kubectl','rollout','status',f'deployment/{d}','-n','default','--timeout=5m'],capture_output=True,text=True,timeout=320)
  if rr.returncode!=0:logger.error(f"Rollout failed: {rr.stderr}");return False,rr.stderr
  logger.info("Rollout complete");return True,"Success"
 except subprocess.TimeoutExpired:logger.error("Timeout");return False,"Timeout"
 except Exception as e:logger.error(str(e));return False,str(e)
@app.route('/health')
def health():return jsonify({'status':'healthy','timestamp':datetime.now().isoformat(),'service':'webhook-receiver'}),200
@app.route('/webhook',methods=['POST'])
def webhook():
 try:
  logger.info("Webhook received");p=request.get_data();d=request.get_json()
  if not d:return jsonify({'error':'No payload'}),400
  if WEBHOOK_SECRET and not validate_signature(p,request.headers.get('X-Hub-Signature','')):return jsonify({'error':'Invalid sig'}),403
  r=d.get('repository',{}).get('repo_name');t=d.get('push_data',{}).get('tag','latest')
  if not r:return jsonify({'error':'No repo'}),400
  logger.info(f"Processing {r}:{t}");dep=REPO_TO_DEPLOYMENT.get(r)
  if not dep:return jsonify({'status':'ignored','message':f'No config for {r}'}),200
  s,m=update_deployment(dep,r,t)
  return jsonify({'status':'success' if s else 'failed','deployment':dep,'image':f'{r}:{t}','message':m,'timestamp':datetime.now().isoformat()}),200 if s else 500
 except Exception as e:logger.error(str(e),exc_info=True);return jsonify({'status':'error','error':str(e),'timestamp':datetime.now().isoformat()}),500
@app.route('/')
def index():return jsonify({'service':'Webhook Receiver','version':'1.0','endpoints':{'health':'/health','webhook':'/webhook'},'repos':list(REPO_TO_DEPLOYMENT.keys())}),200
if __name__=='__main__':logger.info("Starting on :9000");app.run(host='0.0.0.0',port=9000,debug=False)
A
sudo chmod +x /opt/webhook-receiver/webhook_server.py
log "Creating systemd service..."
cat<<'B'|sudo tee /etc/systemd/system/webhook-receiver.service>/dev/null
[Unit]
Description=Docker Hub Webhook Receiver
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/webhook-receiver
ExecStart=/usr/bin/python3 /opt/webhook-receiver/webhook_server.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/webhook-receiver/service.log
StandardError=append:/var/log/webhook-receiver/service-error.log
NoNewPrivileges=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
B
sudo systemctl daemon-reload && sudo systemctl enable webhook-receiver.service
log "Service enabled (not started - kubectl config needed first)"
cat<<'C'|sudo tee /opt/webhook-receiver/README.md>/dev/null
# Webhook Setup Complete
## Next: Configure kubectl
1. On K8s master: kubectl apply -f kubernetes/webhook-rbac.yaml
2. Generate kubeconfig: ./scripts/generate-kubeconfig.sh
3. Copy to webhook server: scp webhook-kubeconfig ec2-user@<IP>:/tmp/
4. On webhook server: sudo mv /tmp/webhook-kubeconfig /root/.kube/config && sudo chmod 600 /root/.kube/config
5. Start service: sudo systemctl start webhook-receiver
## Configure Docker Hub
Add webhook URL for each repo: http://<IP>:9000/webhook
## Commands
sudo systemctl status webhook-receiver
sudo tail -f /var/log/webhook-receiver/webhook.log
curl http://localhost:9000/health
C
log "Setup complete! See /opt/webhook-receiver/README.md for next steps"
