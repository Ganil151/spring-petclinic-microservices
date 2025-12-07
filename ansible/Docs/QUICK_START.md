# Quick Start - Ansible Deployment

## ✅ Completed Steps

1. ✅ **Inventory Setup** - `inventory.ini` configured with all hosts
2. ✅ **Connectivity Test** - All 7 hosts responding to ping
3. ✅ **Galaxy Dependencies** - MySQL role and collections installed
4. ✅ **Group Variables** - All server groups configured
5. ✅ **Playbooks Created** - Common, MySQL, and Site orchestration

---

## 📋 Next Steps

### Step 1: Run Common Setup (RECOMMENDED FIRST)

Apply base configuration to all servers:

```bash
cd /home/ec2-user/workspace/spms-pipeline/ansible
ansible-playbook playbooks/common.yml
```

**What this does:**
- Updates all system packages
- Configures timezone and kernel parameters
- Sets up firewall rules
- Configures SSH hardening
- Installs common utilities

**Expected duration:** 5-10 minutes

---

### Step 2: Deploy MySQL Database

Install and configure MySQL with Petclinic databases:

```bash
ansible-playbook playbooks/mysql.yml
```

**What this does:**
- Installs MySQL Server 8.0
- Creates 3 databases (customers, vets, visits)
- Creates petclinic user with proper permissions
- Configures firewall for remote access
- Verifies installation

**Expected duration:** 10-15 minutes

---

### Step 3: Verify MySQL Deployment

After MySQL playbook completes, verify:

```bash
# Check MySQL service
ansible mysql -m shell -a "systemctl status mysqld"

# Test connection
ansible mysql -m shell -a "mysql -u petclinic -p'petclinic123' -e 'SHOW DATABASES;'"

# View databases
ansible mysql -m debug -a "var=mysql_databases"
```

---

### Step 4: Run Complete Deployment

Or run everything together:

```bash
ansible-playbook playbooks/site.yml
```

This runs all playbooks in sequence:
1. Common setup
2. MySQL installation
3. (Future: Kubernetes cluster)
4. (Future: Monitoring stack)
5. (Future: Application deployment)

---

## 🔍 Useful Commands

### Check Inventory
```bash
ansible-inventory --graph
ansible-inventory --list
```

### Test Connectivity
```bash
ansible all -m ping
ansible mysql -m ping
ansible kube_cluster -m ping
```

### View Variables
```bash
ansible mysql -m debug -a "var=mysql_databases"
ansible k8s_master -m debug -a "var=pod_network_cidr"
```

### Dry Run (Check Mode)
```bash
ansible-playbook playbooks/mysql.yml --check
```

### Verbose Output
```bash
ansible-playbook playbooks/mysql.yml -v
ansible-playbook playbooks/mysql.yml -vvv  # debug
```

### Run Specific Tags
```bash
ansible-playbook playbooks/site.yml --tags mysql
ansible-playbook playbooks/common.yml --tags packages,timezone
```

---

## 📂 File Structure

```
ansible/
├── README.md                    # Complete documentation
├── QUICK_START.md              # This file
├── ansible.cfg                  # Ansible configuration
├── inventory.ini                # Host inventory
├── requirements.yml             # Galaxy requirements
│
├── group_vars/                  # Server configurations
│   ├── all.yml                 # ✅ Common settings
│   ├── mysql.yml               # ✅ MySQL configuration
│   ├── k8s_master.yml          # ✅ K8s master config
│   ├── k8s_primary_workers.yml # ✅ Primary worker config
│   ├── k8s_secondary_workers.yml # ✅ Secondary worker config
│   ├── monitoring.yml          # ✅ Prometheus/Grafana config
│   ├── worker.yml              # ✅ Build server config
│   └── master.yml              # ✅ Control server config
│
└── playbooks/                   # Ansible playbooks
    ├── site.yml                # ✅ Master orchestration
    ├── common.yml              # ✅ Common setup
    └── mysql.yml               # ✅ MySQL deployment
```

---

## 🎯 Recommended Execution Order

1. **Test connectivity first:**
   ```bash
   ansible all -m ping
   ```

2. **Run common setup** (prepares all servers):
   ```bash
   ansible-playbook playbooks/common.yml
   ```

3. **Deploy MySQL** (required for Petclinic):
   ```bash
   ansible-playbook playbooks/mysql.yml
   ```

4. **Verify MySQL** before proceeding:
   ```bash
   ansible mysql -m shell -a "systemctl status mysqld"
   ```

5. **Next:** Create Kubernetes playbooks (k8s-master.yml, k8s-workers.yml)

---

## ⚠️ Important Notes

- **Passwords:** Default passwords are used. Set environment variables in production:
  ```bash
  export MYSQL_ROOT_PASSWORD="your_secure_password"
  export MYSQL_PETCLINIC_PASSWORD="your_petclinic_password"
  ```

- **Firewall:** Playbooks configure firewalld. Ensure AWS security groups allow traffic.

- **SSH Keys:** Ensure `~/.ssh/master_keys.pem` has correct permissions:
  ```bash
  chmod 600 ~/.ssh/master_keys.pem
  ```

- **Idempotency:** All playbooks are idempotent - safe to run multiple times.

---

## 📞 Need Help?

- Check `README.md` for detailed documentation
- Review troubleshooting section for common issues
- Use `-vvv` flag for debug output
- Verify variables with `ansible-debug` module

---

**Ready to start?** Run:
```bash
ansible-playbook playbooks/common.yml
```
