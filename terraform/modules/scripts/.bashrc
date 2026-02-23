# =============================================================================
# 🛡️ SPRING PETCLINIC - INDUSTRIAL RIGOR .bashrc
# =============================================================================

# --- Colorized Prompt (Industrial Style) ---
# Format: [TIME] [USER@HOST] [CWD] $
export PS1="\[\e[32m\][\t] \[\e[36m\]\u@\h \[\e[33m\]\w \[\e[0m\]\$ "

# --- Enhanced History ---
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTTIMEFORMAT="%F %T " # Timestamps for audit trails
shopt -s histappend            # Append to history, don't overwrite

# ==========================================
#        01. System & Navigation
# ==========================================
alias cls='clear'
alias reload='source ~/.bashrc'
alias path='echo $PATH | tr ":" "\n"'
alias l='ls -lah --color=auto'
alias mkdir='mkdir -p'
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../../'
alias h='history | grep'
alias ports='sudo netstat -tulanp'
alias myip='curl -s https://ifconfig.me; echo'
alias df='df -h'
alias free='free -m'

# ==========================================
#        02. Build & Microservices (Java/Maven)
# ==========================================
alias mci='./mvnw clean install'
alias mcp='./mvnw clean package -DskipTests'
alias mct='./mvnw clean test'
alias mrun='./mvnw spring-boot:run'

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

# Kubernetes (The DevSecOps Core)
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpw='kubectl get pods -o wide'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias kl='kubectl logs -f'
alias kexec='kubectl exec -it'
alias kw='watch -n 1 kubectl get pods'
alias k-ps='kubectl get pods --all-namespaces'

# PetClinic EKS Contexts
alias k-pet='kubectl -n spring-petclinic'
alias kgp-pet='kubectl get pods -n spring-petclinic'
alias kl-pet='kubectl logs -f -n spring-petclinic'

# ==========================================
#        04. Infrastructure (Terragrunt/Terraform)
# ==========================================
alias tf='terraform'
alias tg='terragrunt'
alias tga='terragrunt apply'
alias tgaa='terragrunt apply --all'
alias tgp='terragrunt plan'
alias tgpa='terragrunt plan --all'
alias tgd='terragrunt destroy'
alias tgda='terragrunt destroy --all'

# ==========================================
#        05. AWS Cloud Ops
# ==========================================
alias aws-who='aws sts get-caller-identity'
alias aws-ls='aws s3 ls'
alias ec2-ls='aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==\`Name\`].Value|[0],Type:InstanceType,IP:PrivateIpAddress}" --output table'

# ==========================================
#        06. Service Management
# ==========================================
# Jenkins
alias sys-j='sudo systemctl status jenkins'
alias logs-j='sudo journalctl -u jenkins -f'
alias rest-j='sudo systemctl restart jenkins'

# SonarQube (Docker Managed)
alias sys-sonar='docker ps | grep sonarqube'
alias logs-sonar='docker logs -f sonarqube'

# App Logs (Journald)
alias logs-app='sudo journalctl -f'

# --- Industrial Rigor Functions ---
# Find and Kill process by port
kill-port() {
    sudo fuser -k "$1"/tcp
}

# Quick Search in logs
search-logs() {
    sudo journalctl | grep -i "$1"
}
