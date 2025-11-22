#!/usr/bin/env python3
"""
Docker Hub Webhook Receiver for Kubernetes
Listens for Docker Hub webhooks and automatically updates Kubernetes deployments
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import subprocess
import logging
from datetime import datetime

# Configuration
WEBHOOK_PORT = 9000
LOG_FILE = '/var/log/docker-webhook.log'

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)

class WebhookHandler(BaseHTTPRequestHandler):
    """Handle incoming webhook requests from Docker Hub"""
    
    def do_POST(self):
        """Handle POST requests from Docker Hub"""
        try:
            # Read the request body
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            # Parse JSON payload
            payload = json.loads(post_data.decode('utf-8'))
            
            logging.info(f"Received webhook: {json.dumps(payload, indent=2)}")
            
            # Extract repository and tag information
            repo_name = payload.get('repository', {}).get('repo_name', '')
            tag = payload.get('push_data', {}).get('tag', 'latest')
            
            if repo_name:
                # Extract service name (e.g., ganil151/customers-service -> customers-service)
                service_name = repo_name.split('/')[-1]
                
                logging.info(f"Updating deployment: {service_name} to {repo_name}:{tag}")
                
                # Update Kubernetes deployment
                self.update_kubernetes_deployment(service_name, repo_name, tag)
                
                # Send success response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {'status': 'success', 'service': service_name, 'tag': tag}
                self.wfile.write(json.dumps(response).encode())
            else:
                logging.warning("No repository name found in webhook payload")
                self.send_error(400, "Invalid payload")
                
        except Exception as e:
            logging.error(f"Error processing webhook: {str(e)}")
            self.send_error(500, f"Internal error: {str(e)}")
    
    def update_kubernetes_deployment(self, service_name, image_name, tag):
        """Update Kubernetes deployment with new image"""
        try:
            # Build the full image name
            full_image = f"{image_name}:{tag}"
            
            # Update the deployment
            cmd = [
                'kubectl', 'set', 'image',
                f'deployment/{service_name}',
                f'{service_name}={full_image}'
            ]
            
            logging.info(f"Executing: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                logging.info(f"Successfully updated {service_name}")
                logging.info(f"kubectl output: {result.stdout}")
                
                # Wait for rollout to complete
                rollout_cmd = ['kubectl', 'rollout', 'status', f'deployment/{service_name}']
                rollout_result = subprocess.run(rollout_cmd, capture_output=True, text=True, timeout=300)
                
                if rollout_result.returncode == 0:
                    logging.info(f"Rollout completed successfully for {service_name}")
                else:
                    logging.warning(f"Rollout status check failed: {rollout_result.stderr}")
            else:
                logging.error(f"Failed to update deployment: {result.stderr}")
                
        except subprocess.TimeoutExpired:
            logging.error(f"Timeout while updating {service_name}")
        except Exception as e:
            logging.error(f"Error updating deployment: {str(e)}")
    
    def log_message(self, format, *args):
        """Override to use custom logging"""
        logging.info(f"{self.address_string()} - {format % args}")

def run_server():
    """Start the webhook server"""
    server_address = ('', WEBHOOK_PORT)
    httpd = HTTPServer(server_address, WebhookHandler)
    
    logging.info(f"Docker Webhook Receiver started on port {WEBHOOK_PORT}")
    logging.info(f"Logs are being written to {LOG_FILE}")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logging.info("Shutting down webhook receiver...")
        httpd.shutdown()

if __name__ == '__main__':
    run_server()
