# ==========================================
#        01. System & Navigation
# ==========================================
alias cls='clear'
alias reload='source ~/.zshrc'
alias path='echo $PATH | tr ":" "\n"'
alias l='ls -lah --color=auto'
alias mkdir='mkdir -p'
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../../'
alias h='history | grep'
alias ports='netstat -tulanp'
alias myip='curl -s https://ifconfig.me; echo'


# ==========================================
#        03. Container Ops (Docker & K8s)
# ==========================================
# Docker
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpa='docker ps -a'
alias dstats='docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"'
alias dstop='docker stop $(docker ps -q)'
alias dkill='docker rm -f $(docker ps -aq)'
alias dex='docker exec -it'
alias dimg='docker images'
alias dprune='docker system prune -af --volumes'
alias dclean='docker rmi $(docker images -q -f dangling=true)'

# Docker Compose
alias dco='docker-compose'
alias dcup='docker-compose up -d'
alias dcdn='docker-compose down'
alias dcl='docker-compose logs -f'

# Kubernetes
alias k='kubectl'
alias kctx='kubectx'
alias kns='kubens'
alias kgp='kubectl get pods'
alias kgpw='kubectl get pods -o wide'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias kl='kubectl logs -f'
alias kexec='kubectl exec -it'
alias kdelp='kubectl delete pod'
alias kw='watch kubectl get pods'
ksh() { kubectl exec -it "$1" -- /bin/bash || kubectl exec -it "$1" -- /bin/sh; }

# ==========================================
#        04. Infrastructure as Code
# ==========================================
# Terraform
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfa-auto='terraform apply -auto-approve'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tfo='terraform output'
alias tfw='terraform workspace'
alias tff='terraform fmt -recursive'

# ==========================================
#        05. Cloud Platforms
# ==========================================
# --- AWS ---
alias aws-who='aws sts get-caller-identity'
alias aws-ls='aws s3 ls'
alias aws-logs='aws logs tail --follow'
asp() { export AWS_PROFILE=$1; echo "AWS Profile set to: $AWS_PROFILE"; }

# AWS Inventory Suite
alias ec2-ls='aws ec2 describe-instances --region us-east-1 --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==\`Name\`].Value|[0],Type:InstanceType,IP:PrivateIpAddress,SG:SecurityGroups[0].GroupName}" --output table'
alias ec2-audit='aws ec2 describe-instances --region us-east-1 --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==\`Name\`].Value|[0],Type:InstanceType,PubIP:PublicIpAddress,PrivIP:PrivateIpAddress,Launched:LaunchTime,SG:SecurityGroups[0].GroupName}" --output table'
alias ec2-cost='aws ec2 describe-instances --region us-east-1 --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==\`Name\`].Value|[0],Type:InstanceType,State:State.Name}" --output table'
alias ec2-ls-all='aws ec2 describe-instances --region us-east-1 --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==\`Name\`].Value|[0],Type:InstanceType,State:State.Name,IP:PrivateIpAddress,SG:SecurityGroups[0].GroupName}" --output table'

# Connect via SSM
ec2-connect() {
    echo "Starting SSM Session for $1..."
    aws ssm start-session --target "$1"
}


# -----------------------------------------------------------------------------
# 13. POST-INIT VALIDATION — Verify critical tools
# -----------------------------------------------------------------------------
_missing_tools() {
  local tools=("terraform" "kubectl" "docker" "jq" "openssl")
  local missing=()
  for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  [[ ${#missing[@]} -gt 0 ]] && \
    echo "⚠️  Missing tools: ${missing[*]}. Install with: sudo dnf install ${missing[*]}"
  return 0
}
_missing_tools