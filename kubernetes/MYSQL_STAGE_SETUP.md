# MySQL Configuration Stage - Setup Guide

## 🔐 **Required Jenkins Credentials**

You need to create these credentials in Jenkins before using the MySQL configuration stage.

### **1. MySQL Root Credentials**

**Credential ID**: `mysql-root-credentials`
**Type**: Username with password

```
Username: root
Password: PetclinicRoot123!
```

**How to Create**:
1. Go to Jenkins → Manage Jenkins → Credentials
2. Click on "(global)" domain
3. Click "Add Credentials"
4. Select "Username with password"
5. Enter:
   - Username: `root`
   - Password: `PetclinicRoot123!`
   - ID: `mysql-root-credentials`
   - Description: `MySQL Root Credentials`
6. Click "Create"

---

### **2. MySQL Petclinic User Credentials**

**Credential ID**: `mysql-petclinic-credentials`
**Type**: Username with password

```
Username: petclinic_user
Password: PetClinic@12345!
```

**How to Create**:
1. Go to Jenkins → Manage Jenkins → Credentials
2. Click on "(global)" domain
3. Click "Add Credentials"
4. Select "Username with password"
5. Enter:
   - Username: `petclinic_user`
   - Password: `PetClinic@12345!`
   - ID: `mysql-petclinic-credentials`
   - Description: `MySQL Petclinic User Credentials`
6. Click "Create"

---

## 📋 **Required Jenkinsfile Parameters**

Add this parameter to your Jenkinsfile:

```groovy
parameters {
    string(name: 'NODE_LABEL', defaultValue: 'worker-node', description: 'Jenkins agent label')
    string(name: 'EC2_INSTANCE_NAME', defaultValue: 'Spring-Petclinic-Docker', description: 'EC2 instance tag Name')
    string(name: 'SSH_CREDENTIALS_ID', defaultValue: 'master_keys', description: 'SSH credential id for EC2')
    
    // ADD THIS:
    choice(
        name: 'DEPLOYMENT_TARGET',
        choices: ['docker', 'kubernetes', 'both', 'none'],
        description: 'Deployment target (docker, kubernetes, both, or none)'
    )
    booleanParam(
        name: 'CONFIGURE_MYSQL',
        defaultValue: false,
        description: 'Run Ansible to configure MySQL databases'
    )
}
```

---

## ✅ **What the Stage Does**

### **1. Updates Ansible Variables**
- Reads credentials from Jenkins
- Updates `ansible/group_vars/mysql.yml` with credentials
- Ensures Ansible uses Jenkins-managed credentials

### **2. Tests Ansible Connectivity**
- Pings MySQL server via Ansible
- Verifies SSH connection works
- Fails fast if connectivity issues

### **3. Runs Ansible Playbook**
- Executes `ansible/mysql_setup.yml`
- Installs MySQL if needed
- Creates databases and users
- Configures permissions

### **4. Verifies Database Creation**
- Checks if `customers`, `visits`, `vets` databases exist
- Confirms databases are accessible
- Lists all databases

### **5. Verifies User Creation**
- Checks if `petclinic_user` exists
- Verifies user can connect
- Tests user has proper permissions

### **6. Tests Database Access**
- Connects to each database as petclinic_user
- Verifies SELECT permissions
- Ensures user can access all databases

### **7. Checks Schema**
- Looks for tables in each database
- Reports if schema is loaded
- Warns if tables are missing

### **8. Displays MySQL Info**
- Shows MySQL version
- Displays MySQL server IP
- Provides connection string

---

## 🎯 **Expected Output**

```
=== MySQL Configuration ===
MySQL Root User: root
Petclinic User: petclinic_user

✓ Ansible variables updated

=== Testing Ansible Connectivity ===
mysql-server | SUCCESS => {
    "ping": "pong"
}
✓ Ansible connectivity verified

=== Running Ansible Playbook ===
PLAY [Configure MySQL for Spring Petclinic Microservices] ***
...
✓ Ansible playbook completed successfully

=== Verifying Database Creation ===
customers
visits
vets
✓ All required databases exist (customers, visits, vets)

=== Verifying Petclinic User ===
petclinic_user  %
✓ Petclinic user exists: petclinic_user

=== Testing Petclinic User Connection ===
1
✓ Petclinic user can connect successfully

=== Verifying Database Access ===
Testing access to customers database...
✓ Access to customers database verified
Testing access to visits database...
✓ Access to visits database verified
Testing access to vets database...
✓ Access to vets database verified

=== Checking Database Schema ===
Checking tables in customers database...
✓ customers database has 2 tables
Checking tables in visits database...
✓ visits database has 1 tables
Checking tables in vets database...
✓ vets database has 2 tables

=== MySQL Server Information ===
8.0.35

MySQL Server IP: 54.167.194.172

=== MySQL Configuration Complete ===
✓ Databases: customers, visits, vets
✓ User: petclinic_user
✓ Connection: 54.167.194.172:3306
✓ All health checks passed
```

---

## 🔧 **How to Use**

### **Option 1: Run with MySQL Configuration**

```groovy
// In Jenkins, set parameters:
DEPLOYMENT_TARGET = 'kubernetes'
CONFIGURE_MYSQL = true
```

### **Option 2: Skip MySQL Configuration**

```groovy
// In Jenkins, set parameters:
DEPLOYMENT_TARGET = 'kubernetes'
CONFIGURE_MYSQL = false  // Skip if already configured
```

---

## 🚨 **Troubleshooting**

### **Issue 1: Ansible Cannot Connect**

```bash
# Check SSH connectivity manually
ssh -i ~/.ssh/master_keys.pem ec2-user@<mysql-server-ip>

# Check Ansible inventory
cat ansible/inventory.ini

# Test Ansible ping
cd ansible
ansible mysql -i inventory.ini -m ping
```

### **Issue 2: MySQL User Cannot Connect**

```bash
# Check user exists
mysql -u root -p -e "SELECT User, Host FROM mysql.user WHERE User='petclinic_user';"

# Check user permissions
mysql -u root -p -e "SHOW GRANTS FOR 'petclinic_user'@'%';"

# Test connection
mysql -u petclinic_user -p -h <mysql-server-ip> -e "SELECT 1;"
```

### **Issue 3: Databases Not Created**

```bash
# Check databases
mysql -u root -p -e "SHOW DATABASES;"

# Manually create if needed
mysql -u root -p -e "CREATE DATABASE customers;"
mysql -u root -p -e "CREATE DATABASE visits;"
mysql -u root -p -e "CREATE DATABASE vets;"
```

### **Issue 4: Credentials Not Working**

```bash
# Verify Jenkins credentials are set correctly
# Go to Jenkins → Manage Jenkins → Credentials
# Check mysql-root-credentials and mysql-petclinic-credentials

# Test credentials manually
mysql -u root -p<password> -e "SELECT 1;"
mysql -u petclinic_user -p<password> -e "SELECT 1;"
```

---

## 💡 **Best Practices**

1. **Run once per environment** - MySQL configuration is idempotent but doesn't need to run every build
2. **Use Jenkins credentials** - Never hardcode passwords in Jenkinsfile
3. **Verify before K8s deployment** - Ensure MySQL is ready before deploying pods
4. **Check schema** - Verify tables exist before running microservices
5. **Monitor logs** - Review Ansible output for any warnings

---

## 📝 **Integration with Jenkinsfile**

Add the stage after "Verify Docker Deployment":

```groovy
stage('Verify Docker Deployment') {
    // ... existing code ...
}

stage('Configure MySQL Database') {
    when {
        expression { 
            params.DEPLOYMENT_TARGET in ['kubernetes', 'both'] &&
            params.CONFIGURE_MYSQL == true
        }
    }
    steps {
        // ... MySQL configuration code ...
    }
}

stage('Deploy to Kubernetes') {
    // ... K8s deployment code ...
}
```

This ensures MySQL is configured before Kubernetes deployment! 🚀
