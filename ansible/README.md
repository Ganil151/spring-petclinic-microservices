# Ansible Infrastructure Setup Guide
## Spring Petclinic Microservices Deployment

This guide provides step-by-step instructions for deploying and managing the Spring Petclinic Microservices infrastructure using Ansible.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Directory Structure](#directory-structure)
3. [Quick Start](#quick-start)
4. [Detailed Setup Guide](#detailed-setup-guide)
5. [Playbook Execution](#playbook-execution)
6. [Configuration Details](#configuration-details)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

---

## 🔧 Prerequisites

### Required Software
- **Ansible**: Version 2.15+ (installed on control node)
- **Python**: Version 3.9+
- **SSH Access**: SSH key-based authentication to all target servers
- **AWS EC2**: Running instances with appropriate security groups

### Required Access
- SSH private key: `~/.ssh/master_keys.pem` with proper permissions (chmod 600)
- EC2 instances accessible on the network
- Sudo privileges on all target servers

### Environment Variables (Optional)
Set these for enhanced security:
```bash
export MYSQL_ROOT_PASSWORD="your_secure_password"
export MYSQL_PETCLINIC_PASSWORD="your_petclinic_password"
export MYSQL_ADMIN_PASSWORD="your_admin_password"
export GRAFANA_ADMIN_PASSWORD="your_grafana_password"
export JENKINS_ADMIN_PASSWORD="your_jenkins_password"
```

---

## 📁 Directory Structure

```
ansible/
├── README.md                          # This file
├── ansible.cfg                        # Ansible configuration
├── inventory.ini                      # Host inventory
├── requirements.yml                   # Ansible Galaxy requirements
│
├── group_vars/                        # Group-specific variables
│   ├── all.yml                       # Common variables for all hosts
│   ├── master.yml                    # Master server variables
│   ├── worker.yml                    # Worker/build server variables
│   ├── monitoring.yml                # Monitoring server variables
│   ├── mysql.yml                     # MySQL server variables
│   ├── k8s_master.yml                # Kubernetes master variables
│   ├── k8s_primary_workers.yml       # K8s primary worker variables
│   └── k8s_secondary_workers.yml     # K8s secondary worker variables
│
├── playbooks/                         # Ansible playbooks
│   ├── site.yml                      # Main playbook (runs all)
│   ├── common.yml                    # Common setup for all servers
│   ├── mysql.yml                     # MySQL installation & config
│   ├── k8s-cluster.yml               # Complete K8s cluster setup
│   ├── k8s-master.yml                # K8s master node setup
│   ├── k8s-workers.yml               # K8s worker nodes setup
│   ├── monitoring.yml                # Monitoring stack setup
│   └── deploy-petclinic.yml          # Deploy Spring Petclinic
│
└── roles/                            # Custom and Galaxy roles
    └── geerlingguy.mysql/            # MySQL role (from Galaxy)
```

---

## 🚀 Quick Start

### Step 1: Verify Connectivity
Test that Ansible can reach all hosts:
```bash
cd ansible
ansible all -m ping
```

Expected output: All hosts return `SUCCESS` with `"ping": "pong"`

### Step 2: Install Dependencies
Install required Ansible Galaxy roles and collections:
```bash
# Install collections
ansible-galaxy collection install community.mysql --force
ansible-galaxy collection install community.general --force

# Install MySQL role
ansible-galaxy role install geerlingguy.mysql --force
```

### Step 3: Verify Inventory
Check your inventory configuration:
```bash
ansible-inventory --graph --vars
```

### Step 4: Run Common Setup
Apply common configuration to all servers:
```bash
ansible-playbook playbooks/common.yml
```

### Step 5: Deploy Infrastructure
Run the complete deployment:
```bash
ansible-playbook playbooks/site.yml
```

---

## 📖 Detailed Setup Guide

### Phase 1: Initial Preparation

#### Step 1.1: Update Inventory
Edit `inventory.ini` to match your infrastructure:
```bash
vim inventory.ini
```

Verify the following:
- ✅ Correct IP addresses for all hosts
- ✅ Proper SSH key path
- ✅ Correct ansible_user (should be `ec2-user` for Amazon Linux)

#### Step 1.2: Test SSH Connectivity
Manually SSH to verify access:
```bash
ssh -i ~/.ssh/master_keys.pem ec2-user@<host-ip>
```

#### Step 1.3: Verify Ansible Configuration
Check Ansible can find your inventory:
```bash
ansible-config dump | grep DEFAULT_HOST_LIST
ansible-inventory --list
```

---

### Phase 2: Install Ansible Galaxy Dependencies

#### Step 2.1: Review Requirements
View what will be installed:
```bash
cat requirements.yml
```

#### Step 2.2: Install Galaxy Collections and Roles

**Important:** Due to version caching issues, install directly rather than using the requirements file:

```bash
# Install collections
ansible-galaxy collection install community.mysql --force
ansible-galaxy collection install community.general --force

# Install MySQL role (latest stable version)
ansible-galaxy role install geerlingguy.mysql --force
```

This installs:
- `geerlingguy.mysql` - MySQL installation and configuration
- `community.mysql` collection - MySQL management modules
- `community.general` collection - General utility modules

#### Step 2.3: Verify Installation
```bash
ansible-galaxy role list
ansible-galaxy collection list
```

Expected output should include `geerlingguy.mysql` (version 6.0.0 or newer)

---

### Phase 3: Common Infrastructure Setup

Apply base configuration to all servers:

#### Step 3.1: Run Common Playbook
```bash
ansible-playbook playbooks/common.yml
```

This playbook:
- ✅ Updates system packages
- ✅ Configures timezone
- ✅ Sets up kernel parameters
- ✅ Configures firewall
- ✅ Installs common utilities
- ✅ Configures SSH hardening
- ✅ Sets up NTP

#### Step 3.2: Verify Common Setup
```bash
ansible all -m shell -a "timedatectl | grep 'Time zone'"
ansible all -m shell -a "cat /proc/sys/net/ipv4/ip_forward"
```

---

### Phase 4: MySQL Database Setup

#### Step 4.1: Review MySQL Configuration
Check the MySQL variables:
```bash
ansible mysql -m debug -a "var=mysql_databases"
ansible mysql -m debug -a "var=mysql_users"
```

#### Step 4.2: Run MySQL Playbook
```bash
ansible-playbook playbooks/mysql.yml
```

This playbook:
- ✅ Installs MySQL Server 8.0
- ✅ Configures MySQL for remote access
- ✅ Creates databases: `petclinic_customers`, `petclinic_vets`, `petclinic_visits`
- ✅ Creates users: `petclinic`, `petclinic_admin`
- ✅ Optimizes MySQL performance settings
- ✅ Enables slow query logging

#### Step 4.3: Verify MySQL Installation
Test MySQL connectivity:
```bash
ansible mysql -m shell -a "systemctl status mysqld"
ansible mysql -m shell -a "mysql -u root -p'{{ mysql_root_password }}' -e 'SHOW DATABASES;'"
```

Test database creation:
```bash
ansible mysql -m shell -a "mysql -u petclinic -p'petclinic123' -e 'SHOW DATABASES;'"
```

#### Step 4.4: Test Remote Connectivity
From your control node:
```bash
mysql -h <mysql-server-ip> -u petclinic -p'petclinic123' -e "SHOW DATABASES;"
```

---

### Phase 5: Kubernetes Cluster Setup

#### Step 5.1: Setup Kubernetes Master

##### Run Master Playbook
```bash
ansible-playbook playbooks/k8s-master.yml
```

This playbook:
- ✅ Disables swap
- ✅ Configures SELinux (permissive mode)
- ✅ Installs container runtime (containerd)
- ✅ Installs kubeadm, kubelet, kubectl
- ✅ Initializes Kubernetes cluster
- ✅ Installs Calico CNI plugin
- ✅ Configures kubeconfig for ec2-user

##### Verify Master Node
```bash
ansible k8s_master -m shell -a "kubectl get nodes"
ansible k8s_master -m shell -a "kubectl get pods -n kube-system"
```

##### Retrieve Join Command
The join token is saved automatically. To view it:
```bash
ansible k8s_master -m shell -a "cat /tmp/k8s_join_command.sh"
```

#### Step 5.2: Setup Kubernetes Workers

##### Run Workers Playbook
```bash
ansible-playbook playbooks/k8s-workers.yml
```

This playbook:
- ✅ Installs container runtime on workers
- ✅ Installs kubeadm and kubelet
- ✅ Joins workers to the cluster
- ✅ Applies node labels (primary/secondary)
- ✅ Configures resource limits

##### Verify Worker Nodes
```bash
ansible k8s_master -m shell -a "kubectl get nodes -o wide"
ansible k8s_master -m shell -a "kubectl get nodes --show-labels"
```

Expected output: 3 nodes (1 master, 2 workers) in `Ready` state

#### Step 5.3: Complete K8s Cluster Setup (Alternative)
Or run the complete cluster setup in one command:
```bash
ansible-playbook playbooks/k8s-cluster.yml
```

---

### Phase 6: Monitoring Stack Setup

#### Step 6.1: Deploy Prometheus & Grafana
```bash
ansible-playbook playbooks/monitoring.yml
```

This playbook:
- ✅ Installs Prometheus
- ✅ Configures scrape targets (K8s, MySQL, Spring Boot)
- ✅ Installs Grafana
- ✅ Configures Prometheus datasource
- ✅ Installs Node Exporter
- ✅ Installs MySQL Exporter

#### Step 6.2: Access Monitoring UIs

**Prometheus:**
```
http://<monitoring-server-ip>:9090
```

**Grafana:**
```
http://<monitoring-server-ip>:3000
Username: admin
Password: <GRAFANA_ADMIN_PASSWORD or admin123>
```

#### Step 6.3: Verify Metrics Collection
```bash
# Check Prometheus targets
curl http://<monitoring-server-ip>:9090/api/v1/targets

# Check Node Exporter
curl http://<monitoring-server-ip>:9100/metrics
```

---

### Phase 7: Deploy Spring Petclinic Microservices

#### Step 7.1: Prepare Kubernetes Manifests
Ensure your Kubernetes manifests are ready in the `kubernetes/` directory.

#### Step 7.2: Run Deployment Playbook
```bash
ansible-playbook playbooks/deploy-petclinic.yml
```

This playbook:
- ✅ Creates Kubernetes namespaces
- ✅ Deploys ConfigMaps and Secrets
- ✅ Deploys microservices
- ✅ Creates Services and Ingress
- ✅ Waits for pods to be ready

#### Step 7.3: Verify Deployment
```bash
ansible k8s_master -m shell -a "kubectl get pods -n petclinic"
ansible k8s_master -m shell -a "kubectl get svc -n petclinic"
ansible k8s_master -m shell -a "kubectl get ingress -n petclinic"
```

#### Step 7.4: Check Application Health
```bash
# Port-forward to access services locally
ansible k8s_master -m shell -a "kubectl port-forward -n petclinic svc/api-gateway 8080:8080 &"

# Or access via NodePort
ansible k8s_master -m shell -a "kubectl get svc -n petclinic | grep NodePort"
```

---

## 🎯 Playbook Execution

### Running Individual Playbooks

#### Common Setup
```bash
ansible-playbook playbooks/common.yml
```

#### MySQL Only
```bash
ansible-playbook playbooks/mysql.yml
```

#### Kubernetes Master Only
```bash
ansible-playbook playbooks/k8s-master.yml
```

#### Kubernetes Workers Only
```bash
ansible-playbook playbooks/k8s-workers.yml
```

#### Monitoring Only
```bash
ansible-playbook playbooks/monitoring.yml
```

### Running the Complete Stack
```bash
ansible-playbook playbooks/site.yml
```

### Advanced Execution Options

#### Dry Run (Check Mode)
```bash
ansible-playbook playbooks/site.yml --check
```

#### Verbose Output
```bash
ansible-playbook playbooks/site.yml -v    # verbose
ansible-playbook playbooks/site.yml -vv   # more verbose
ansible-playbook playbooks/site.yml -vvv  # debug level
```

#### Limit to Specific Hosts
```bash
ansible-playbook playbooks/mysql.yml --limit mysql
ansible-playbook playbooks/k8s-workers.yml --limit k8s-worker1-server
```

#### Run Specific Tags
```bash
ansible-playbook playbooks/site.yml --tags "mysql,k8s"
ansible-playbook playbooks/site.yml --skip-tags "monitoring"
```

#### Start at Specific Task
```bash
ansible-playbook playbooks/mysql.yml --start-at-task "Create MySQL databases"
```

---

## ⚙️ Configuration Details

### Group Variables Priority

Variables are applied in the following order (last wins):
1. `group_vars/all.yml` - Applied to all hosts
2. `group_vars/<group>.yml` - Applied to specific group
3. `inventory.ini` vars - Host-specific overrides
4. Command-line extra vars - Highest priority

### Overriding Variables

#### Via Command Line
```bash
ansible-playbook playbooks/mysql.yml -e "mysql_root_password=NewPassword123"
```

#### Via Inventory
Edit `inventory.ini` and add host-specific vars:
```ini
mysql-server ansible_host=54.161.13.187 mysql_root_password=CustomPassword
```

#### Via Environment Variables
Already configured in `group_vars/mysql.yml`:
```yaml
mysql_root_password: "{{ lookup('env', 'MYSQL_ROOT_PASSWORD') | default('Petclinic@2024', true) }}"
```

### MySQL Configuration

**Key Variables** (in `group_vars/mysql.yml`):
- `mysql_databases` - List of databases to create
- `mysql_users` - List of database users
- `mysql_bind_address` - Network binding (0.0.0.0 for remote access)
- `mysql_innodb_buffer_pool_size` - Performance tuning

**Databases Created:**
- `petclinic_customers` - Customer service data
- `petclinic_vets` - Veterinarian service data
- `petclinic_visits` - Visits service data

**Users Created:**
- `petclinic` - Application user (access to all 3 databases)
- `petclinic_admin` - Admin user (full privileges)

### Kubernetes Configuration

**Key Variables:**
- `pod_network_cidr: 10.244.0.0/16` - Pod network range
- `service_cidr: 10.96.0.0/12` - Service network range
- `cni_plugin: calico` - Network plugin

**Node Labels:**
- Primary worker: `workload-type: primary`
- Secondary worker: `workload-type: secondary`

---

## 🔍 Troubleshooting

### Issue: "UNREACHABLE!" Error

**Problem:** Ansible cannot connect to host
```
mysql-server | UNREACHABLE! => {
    "msg": "Failed to connect to the host via ssh"
}
```

**Solutions:**
1. Verify SSH key permissions:
   ```bash
   chmod 600 ~/.ssh/master_keys.pem
   ```

2. Test manual SSH:
   ```bash
   ssh -i ~/.ssh/master_keys.pem ec2-user@<host-ip>
   ```

3. Check security groups (AWS):
   - Port 22 must be open from your control node

4. Verify inventory has correct IP:
   ```bash
   ansible mysql -m debug -a "var=ansible_host"
   ```

---

### Issue: MySQL "Authentication Failed"

**Problem:** Cannot connect to MySQL after installation

**Solutions:**
1. Check MySQL is running:
   ```bash
   ansible mysql -m shell -a "systemctl status mysqld"
   ```

2. Retrieve temporary root password (first install):
   ```bash
   ansible mysql -m shell -a "grep 'temporary password' /var/log/mysqld.log"
   ```

3. Reset root password manually:
   ```bash
   ansible mysql -m shell -a "mysql -u root --connect-expired-password -p'<temp_password>' -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY 'NewPassword123!'; FLUSH PRIVILEGES;\""
   ```

4. Check firewall:
   ```bash
   ansible mysql -m shell -a "firewall-cmd --list-ports"
   ```

---

### Issue: Kubernetes Nodes NotReady

**Problem:** K8s nodes stuck in `NotReady` state

**Solutions:**
1. Check CNI plugin status:
   ```bash
   ansible k8s_master -m shell -a "kubectl get pods -n kube-system | grep calico"
   ```

2. Verify kubelet is running:
   ```bash
   ansible kube_cluster -m shell -a "systemctl status kubelet"
   ```

3. Check logs:
   ```bash
   ansible k8s_master -m shell -a "kubectl logs -n kube-system -l k8s-app=calico-node"
   ansible kube_cluster -m shell -a "journalctl -u kubelet -n 50"
   ```

4. Verify swap is disabled:
   ```bash
   ansible kube_cluster -m shell -a "free -h | grep Swap"
   ```

---

### Issue: "FAILED! => msg: Aborting, target uses selinux but python bindings aren't installed"

**Solution:**
```bash
ansible all -m raw -a "yum install -y python3-libselinux"
```

---

### Issue: Playbook Hangs or Times Out

**Solutions:**
1. Increase timeout in `ansible.cfg`:
   ```ini
   [defaults]
   timeout = 60
   ```

2. Run with verbose output to see where it hangs:
   ```bash
   ansible-playbook playbooks/site.yml -vvv
   ```

3. Check if target server is under high load:
   ```bash
   ansible all -m shell -a "uptime"
   ```

---

### Debug Commands

#### Check Facts
```bash
ansible <host> -m setup
ansible <host> -m setup -a "filter=ansible_default_ipv4"
```

#### Test Connectivity
```bash
ansible all -m ping
ansible all -m shell -a "hostname"
```

#### Check Variables
```bash
ansible <group> -m debug -a "var=<variable_name>"
ansible mysql -m debug -a "var=mysql_databases"
```

#### Validate Syntax
```bash
ansible-playbook playbooks/site.yml --syntax-check
```

#### List Hosts
```bash
ansible-playbook playbooks/site.yml --list-hosts
```

#### List Tasks
```bash
ansible-playbook playbooks/site.yml --list-tasks
```

---

## 🔄 Maintenance

### Update Galaxy Roles
```bash
ansible-galaxy install -r requirements.yml --force
```

### Backup Critical Data

#### Backup MySQL Databases
```bash
ansible mysql -m shell -a "mysqldump -u root -p'{{ mysql_root_password }}' --all-databases > /tmp/mysql_backup.sql"
ansible mysql -m fetch -a "src=/tmp/mysql_backup.sql dest=./backups/mysql_backup_$(date +%Y%m%d).sql flat=yes"
```

#### Backup Kubernetes etcd
```bash
ansible k8s_master -m shell -a "kubectl -n kube-system exec etcd-<master-hostname> -- etcdctl snapshot save /tmp/etcd-backup.db"
```

### Update System Packages
```bash
ansible all -m yum -a "name=* state=latest" --become
```

### Restart Services
```bash
ansible mysql -m service -a "name=mysqld state=restarted" --become
ansible kube_cluster -m service -a "name=kubelet state=restarted" --become
```

---

## 📚 Additional Resources

### Ansible Documentation
- [Ansible Official Docs](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/)
- [geerlingguy.mysql Role](https://github.com/geerlingguy/ansible-role-mysql)

### Kubernetes Documentation
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Calico CNI](https://docs.tigera.io/calico/latest/about/)
- [kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)

### Spring Petclinic
- [Spring Petclinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)

---

## 📧 Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Ansible logs: `/var/log/ansible.log`
3. Check system logs: `journalctl -xe`

---

**Last Updated:** 2024-12-04
**Ansible Version:** 2.15.3
**Kubernetes Version:** 1.28
**MySQL Version:** 8.0
