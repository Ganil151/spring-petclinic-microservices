# Ansible Command Reference & Diagnostics

## 🚀 Quick Command Reference

### **Essential Ansible Commands**

```bash
# Check Ansible version
ansible --version

# List all hosts in inventory
ansible all -i inventory.ini --list-hosts

# Ping all hosts
ansible all -i inventory.ini -m ping

# Check connectivity to specific group
ansible mysql -i inventory.ini -m ping

# View inventory graph
ansible-inventory -i inventory.ini --graph

# View inventory variables
ansible-inventory -i inventory.ini --list

# Run ad-hoc command on all hosts
ansible all -i inventory.ini -a "uptime"

# Run command with sudo
ansible all -i inventory.ini -b -a "systemctl status mysqld"
```

---

## 📋 **Playbook Execution Commands**

### **Basic Playbook Runs**

```bash
# Run playbook
ansible-playbook -i inventory.ini mysql_setup.yml

# Run with verbose output
ansible-playbook -i inventory.ini mysql_setup.yml -v
ansible-playbook -i inventory.ini mysql_setup.yml -vv
ansible-playbook -i inventory.ini mysql_setup.yml -vvv  # Very verbose

# Dry run (check mode)
ansible-playbook -i inventory.ini mysql_setup.yml --check

# Show differences
ansible-playbook -i inventory.ini mysql_setup.yml --check --diff

# Run specific tags
ansible-playbook -i inventory.ini mysql_setup.yml --tags "install"

# Skip specific tags
ansible-playbook -i inventory.ini mysql_setup.yml --skip-tags "install"

# Limit to specific hosts
ansible-playbook -i inventory.ini mysql_setup.yml --limit mysql-server

# Start at specific task
ansible-playbook -i inventory.ini mysql_setup.yml --start-at-task="Create databases"

# Step through tasks interactively
ansible-playbook -i inventory.ini mysql_setup.yml --step
```

### **Monitoring Stack Playbook**

```bash
# Run monitoring setup
ansible-playbook -i inventory.ini monitoring_setup.yml

# Check what will change
ansible-playbook -i inventory.ini monitoring_setup.yml --check --diff

# Run with extra variables
ansible-playbook -i inventory.ini monitoring_setup.yml -e "prometheus_port=9091"
```

---

## 🔍 **Diagnostic Commands**

### **Inventory Diagnostics**

```bash
# Verify inventory syntax
ansible-inventory -i inventory.ini --list

# Check if inventory file has hidden characters
cat -A inventory.ini

# View specific host variables
ansible-inventory -i inventory.ini --host mysql-server

# Test SSH connectivity
ansible mysql -i inventory.ini -m ping -vvv

# Check Python interpreter
ansible mysql -i inventory.ini -m setup -a "filter=ansible_python*"
```

### **Connection Testing**

```bash
# Test SSH connection manually
ssh -i /home/ec2-user/.ssh/master_keys.pem ec2-user@<mysql-server-ip>

# Test with Ansible
ansible mysql -i inventory.ini -m shell -a "hostname"

# Check if Python is installed
ansible mysql -i inventory.ini -m raw -a "which python3"

# Verify sudo access
ansible mysql -i inventory.ini -b -m shell -a "whoami"
```

### **MySQL Diagnostics**

```bash
# Check if MySQL is running
ansible mysql -i inventory.ini -b -m shell -a "systemctl status mysqld"

# Check MySQL version
ansible mysql -i inventory.ini -b -m shell -a "mysql --version"

# Test MySQL connection
ansible mysql -i inventory.ini -b -m shell -a "mysql -u root -ppetclinic -e 'SHOW DATABASES;'"

# Check PyMySQL installation
ansible mysql -i inventory.ini -m shell -a "python3 -c 'import pymysql; print(pymysql.__version__)'"

# Check MySQL port
ansible mysql -i inventory.ini -m shell -a "netstat -tuln | grep 3306"
```

### **Monitoring Stack Diagnostics**

```bash
# Check Prometheus status
ansible monitor-server -i inventory.ini -b -m shell -a "systemctl status prometheus"

# Check Grafana status
ansible monitor-server -i inventory.ini -b -m shell -a "systemctl status grafana-server"

# Check Node Exporter status
ansible monitor-server -i inventory.ini -b -m shell -a "systemctl status node_exporter"

# Test Prometheus endpoint
ansible monitor-server -i inventory.ini -m shell -a "curl -s http://localhost:9090/-/healthy"

# Test Grafana endpoint
ansible monitor-server -i inventory.ini -m shell -a "curl -s http://localhost:3000/api/health"

# Check Prometheus targets
ansible monitor-server -i inventory.ini -m shell -a "curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health}'"
```

---

## 🛠️ **Troubleshooting Commands**

### **Common Issues**

#### **1. Inventory File Issues**

```bash
# Remove hidden characters (Windows CRLF)
sudo sed -i 's/\r$//' /etc/ansible/inventory.ini

# Convert DOS to Unix format
sudo dos2unix /etc/ansible/inventory.ini

# Remove BOM (Byte Order Mark)
sudo iconv -f utf-8 -t utf-8 -c /etc/ansible/inventory.ini -o /tmp/inv_clean.ini
sudo mv /tmp/inv_clean.ini /etc/ansible/inventory.ini

# Recreate inventory file cleanly
sudo bash -c 'cat > /etc/ansible/inventory.ini <<EOF
[mysql]
mysql-server ansible_host=<IP> ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/.ssh/master_keys.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF'
```

#### **2. SSH Connection Issues**

```bash
# Test SSH key permissions
ls -la /home/ec2-user/.ssh/master_keys.pem
chmod 600 /home/ec2-user/.ssh/master_keys.pem

# Test SSH connection
ssh -i /home/ec2-user/.ssh/master_keys.pem -v ec2-user@<mysql-server-ip>

# Add host to known_hosts
ssh-keyscan -H <mysql-server-ip> >> ~/.ssh/known_hosts

# Disable host key checking (testing only)
export ANSIBLE_HOST_KEY_CHECKING=False
```

#### **3. Python/PyMySQL Issues**

```bash
# Install PyMySQL on remote host
ansible mysql -i inventory.ini -b -m yum -a "name=python3-PyMySQL state=present"

# Or using pip
ansible mysql -i inventory.ini -b -m pip -a "name=PyMySQL state=present executable=pip3"

# Verify installation
ansible mysql -i inventory.ini -m shell -a "python3 -c 'import pymysql; print(\"OK\")'"
```

#### **4. MySQL Connection Issues**

```bash
# Check MySQL is listening on all interfaces
ansible mysql -i inventory.ini -b -m shell -a "grep bind-address /etc/my.cnf"

# Restart MySQL
ansible mysql -i inventory.ini -b -m service -a "name=mysqld state=restarted"

# Check MySQL error log
ansible mysql -i inventory.ini -b -m shell -a "tail -50 /var/log/mysqld.log"

# Test root login
ansible mysql -i inventory.ini -b -m shell -a "mysql -u root -ppetclinic -e 'SELECT 1'"
```

---

## 📊 **Useful Ad-Hoc Commands**

### **System Information**

```bash
# Get OS information
ansible all -i inventory.ini -m setup -a "filter=ansible_distribution*"

# Check disk space
ansible all -i inventory.ini -m shell -a "df -h"

# Check memory
ansible all -i inventory.ini -m shell -a "free -h"

# Check CPU info
ansible all -i inventory.ini -m shell -a "lscpu | grep -E 'Model name|CPU\(s\)'"

# Check uptime
ansible all -i inventory.ini -m shell -a "uptime"
```

### **Package Management**

```bash
# Install package
ansible mysql -i inventory.ini -b -m yum -a "name=vim state=present"

# Update all packages
ansible all -i inventory.ini -b -m yum -a "name=* state=latest"

# Remove package
ansible mysql -i inventory.ini -b -m yum -a "name=httpd state=absent"

# Check if package is installed
ansible mysql -i inventory.ini -m shell -a "rpm -qa | grep mysql"
```

### **Service Management**

```bash
# Start service
ansible mysql -i inventory.ini -b -m service -a "name=mysqld state=started"

# Stop service
ansible mysql -i inventory.ini -b -m service -a "name=mysqld state=stopped"

# Restart service
ansible mysql -i inventory.ini -b -m service -a "name=mysqld state=restarted"

# Enable service
ansible mysql -i inventory.ini -b -m service -a "name=mysqld enabled=yes"

# Check service status
ansible mysql -i inventory.ini -b -m shell -a "systemctl status mysqld"
```

### **File Operations**

```bash
# Copy file to remote
ansible mysql -i inventory.ini -m copy -a "src=/local/file dest=/remote/file"

# Create directory
ansible mysql -i inventory.ini -b -m file -a "path=/opt/app state=directory mode=0755"

# Remove file
ansible mysql -i inventory.ini -b -m file -a "path=/tmp/test state=absent"

# Check if file exists
ansible mysql -i inventory.ini -m stat -a "path=/etc/my.cnf"

# Get file content
ansible mysql -i inventory.ini -m slurp -a "src=/etc/my.cnf" | jq -r '.content' | base64 -d
```

---

## 🔐 **Ansible Vault Commands**

```bash
# Create encrypted file
ansible-vault create secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Encrypt existing file
ansible-vault encrypt group_vars/mysql.yml

# Decrypt file
ansible-vault decrypt group_vars/mysql.yml

# View encrypted file
ansible-vault view secrets.yml

# Run playbook with vault password
ansible-playbook -i inventory.ini mysql_setup.yml --ask-vault-pass

# Run with vault password file
ansible-playbook -i inventory.ini mysql_setup.yml --vault-password-file ~/.vault_pass
```

---

## 📝 **Playbook Syntax Validation**

```bash
# Check playbook syntax
ansible-playbook mysql_setup.yml --syntax-check

# Lint playbook (requires ansible-lint)
ansible-lint mysql_setup.yml

# List all tasks in playbook
ansible-playbook -i inventory.ini mysql_setup.yml --list-tasks

# List all tags in playbook
ansible-playbook -i inventory.ini mysql_setup.yml --list-tags

# List all hosts affected
ansible-playbook -i inventory.ini mysql_setup.yml --list-hosts
```

---

## 🎯 **Performance & Optimization**

```bash
# Run with multiple forks (parallel execution)
ansible-playbook -i inventory.ini mysql_setup.yml -f 10

# Profile playbook execution time
ANSIBLE_CALLBACK_WHITELIST=profile_tasks ansible-playbook -i inventory.ini mysql_setup.yml

# Enable pipelining for faster execution
export ANSIBLE_PIPELINING=True
ansible-playbook -i inventory.ini mysql_setup.yml

# Disable fact gathering (if not needed)
ansible-playbook -i inventory.ini mysql_setup.yml --skip-tags always -e "gather_facts=no"
```

---

## 📚 **Ansible Galaxy Commands**

```bash
# Install role from Galaxy
ansible-galaxy install geerlingguy.mysql

# Install from requirements file
ansible-galaxy install -r requirements.yml

# List installed roles
ansible-galaxy list

# Remove role
ansible-galaxy remove geerlingguy.mysql

# Search for roles
ansible-galaxy search mysql

# Create new role
ansible-galaxy init my_role
```

---

## 🔄 **Continuous Integration**

### **Jenkins Integration**

```groovy
// Jenkinsfile stage
stage('Run Ansible Playbook') {
    steps {
        sh '''
            ansible-playbook -i /etc/ansible/inventory.ini \
                             /etc/ansible/mysql_setup.yml \
                             --extra-vars "mysql_root_password=${MYSQL_ROOT_PASSWORD}"
        '''
    }
}
```

### **GitLab CI Integration**

```yaml
# .gitlab-ci.yml
deploy_mysql:
  stage: deploy
  script:
    - ansible-playbook -i inventory.ini mysql_setup.yml
  only:
    - main
```

---

## 🐛 **Debug Mode**

```bash
# Enable debug output
export ANSIBLE_DEBUG=True
ansible-playbook -i inventory.ini mysql_setup.yml

# Show all variables for a host
ansible mysql-server -i inventory.ini -m debug -a "var=hostvars[inventory_hostname]"

# Debug specific variable
ansible-playbook -i inventory.ini mysql_setup.yml -e "debug_var=mysql_root_password" --tags debug
```

---

## 📖 **Quick Reference Table**

| Command | Description |
|---------|-------------|
| `ansible all -m ping` | Ping all hosts |
| `ansible-playbook playbook.yml` | Run playbook |
| `ansible-playbook playbook.yml --check` | Dry run |
| `ansible-playbook playbook.yml -vvv` | Verbose output |
| `ansible-inventory --list` | List inventory |
| `ansible-vault create file.yml` | Create encrypted file |
| `ansible-galaxy install role` | Install role |
| `ansible all -m setup` | Gather facts |
| `ansible all -b -m yum -a "name=pkg"` | Install package |
| `ansible all -m service -a "name=svc state=restarted"` | Restart service |

---

## 🚨 **Emergency Commands**

```bash
# Force kill all Ansible processes
pkill -9 ansible

# Clear Ansible cache
rm -rf ~/.ansible/tmp/*

# Reset SSH known_hosts
rm ~/.ssh/known_hosts

# Force reinstall Ansible
sudo pip3 uninstall ansible -y
sudo pip3 install ansible

# Check Ansible configuration
ansible-config dump

# View Ansible log
tail -f /var/log/ansible.log  # if logging is configured
```

---

## 💡 **Pro Tips**

1. **Always use `-i inventory.ini`** to specify inventory explicitly
2. **Use `--check --diff`** before applying changes
3. **Enable fact caching** for faster playbook runs
4. **Use tags** to run specific parts of playbooks
5. **Keep sensitive data in Ansible Vault**
6. **Use roles** for reusable code
7. **Test playbooks** in development environment first
8. **Use `--limit`** to target specific hosts
9. **Enable callback plugins** for better output
10. **Document your playbooks** with comments

---

## 📞 **Getting Help**

```bash
# Ansible help
ansible --help
ansible-playbook --help

# Module documentation
ansible-doc mysql_db
ansible-doc mysql_user
ansible-doc yum

# List all modules
ansible-doc -l

# Search for modules
ansible-doc -l | grep mysql
```

---

## ✅ **Health Check Script**

Create this script for quick health checks:

```bash
#!/bin/bash
# ansible-health-check.sh

echo "=== Ansible Health Check ==="
echo ""

echo "1. Ansible Version:"
ansible --version | head -1

echo ""
echo "2. Inventory Hosts:"
ansible all -i inventory.ini --list-hosts

echo ""
echo "3. Connectivity Test:"
ansible all -i inventory.ini -m ping

echo ""
echo "4. Python Interpreter:"
ansible all -i inventory.ini -m shell -a "python3 --version"

echo ""
echo "5. Disk Space:"
ansible all -i inventory.ini -m shell -a "df -h /"

echo ""
echo "=== Health Check Complete ==="
```

Run with: `bash ansible-health-check.sh`
