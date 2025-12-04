# Ansible Vault - Secure Credential Management Guide

## 🔐 Overview

Ansible Vault encrypts sensitive data (passwords, API keys, certificates) so they can be safely stored in version control. This guide shows you how to use it for the Spring Petclinic infrastructure.

---

## 📋 What We've Set Up

### **Credential Priority System** (3-Tier Fallback)

All sensitive variables now follow this priority:

1. **Vault Variables** (Production) - Highest priority
2. **Environment Variables** (CI/CD) - Medium priority  
3. **Hardcoded Defaults** (Development only) - Lowest priority

Example from `group_vars/mysql.yml`:
```yaml
mysql_root_password: "{{ vault_mysql_root_password | default(lookup('env', 'MYSQL_ROOT_PASSWORD') | default('Petclinic@2024', true)) }}"
```

**This means:**
- ✅ **Production:** Use encrypted vault password
- ✅ **CI/CD:** Use environment variable
- ✅ **Development:** Use default (for quick testing)

---

## 🚀 Quick Start (Production Setup)

### Step 1: Edit Vault\File with Your Passwords

```bash
cd ansible

# Edit the vault file (currently unencrypted)
vim group_vars/vault.yml
```

**Change these to your secure passwords:**
```yaml
vault_mysql_root_password: "YOUR_SUPER_SECURE_PASSWORD_HERE"
vault_mysql_petclinic_password: "ANOTHER_SECURE_PASSWORD"
vault_mysql_admin_password: "ADMIN_SECURE_PASSWORD"
vault_grafana_admin_password: "GRAFANA_PASSWORD"
vault_jenkins_admin_password: "JENKINS_PASSWORD"
```

### Step 2: Encrypt the Vault File

```bash
# Create a vault password file (keep this VERY secure!)
echo "YourVaultPassword123!" > ~/.vault_pass.txt
chmod 600 ~/.vault_pass.txt

# Encrypt the vault file
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass.txt
```

**Or use interactive mode:**
```bash
ansible-vault encrypt group_vars/vault.yml
# Enter password when prompted
```

### Step 3: Configure Ansible to Use Vault Password

Add to `ansible.cfg`:
```ini
[defaults]
vault_password_file = ~/.vault_pass.txt
```

**Or** use the environment variable:
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass.txt
```

### Step 4: Run Playbooks (Now Uses Encrypted Credentials)

```bash
# Playbooks will automatically decrypt and use vault variables
ansible-playbook playbooks/mysql.yml

# Or specify vault password file explicitly
ansible-playbook playbooks/mysql.yml --vault-password-file ~/.vault_pass.txt

# Or prompt for vault password
ansible-playbook playbooks/mysql.yml --ask-vault-pass
```

---

## 🔧 Vault Management Commands

### **Create/Encrypt a New Vault File**
```bash
ansible-vault create group_vars/vault.yml
```

### **Edit an Encrypted Vault File**
```bash
# Will decrypt, open editor, then re-encrypt
ansible-vault edit group_vars/vault.yml
```

### **View Encrypted File Contents**
```bash
# View without editing
ansible-vault view group_vars/vault.yml
```

### **Encrypt an Existing Unencrypted File**
```bash
ansible-vault encrypt group_vars/vault.yml
```

### **Decrypt a Vault File** (Temporarily)
```bash
# Decrypt to plaintext (BE CAREFUL!)
ansible-vault decrypt group_vars/vault.yml

# Re-encrypt when done
ansible-vault encrypt group_vars/vault.yml
```

### **Change Vault Password**
```bash
ansible-vault rekey group_vars/vault.yml
```

---

## 📁 File Organization

### **Recommended Structure:**

```
group_vars/
├── all.yml                    # Non-sensitive common variables
├── mysql.yml                  # MySQL config (references vault vars)
├── vault.yml                  # 🔒 ENCRYPTED - All sensitive data
├── k8s_master.yml             # K8s config
└── ...
```

**Best Practice:** Keep ONE encrypted vault file per environment:
- `group_vars/production/vault.yml`
- `group_vars/staging/vault.yml`  
- `group_vars/development/vault.yml`

---

## 🎯 Usage Scenarios

### **Scenario 1: Production Deployment (RECOMMENDED)**

```bash
# 1. Update vault with production passwords
ansible-vault edit group_vars/vault.yml

# 2. Run playbook (will use vault credentials)
ansible-playbook playbooks/mysql.yml --vault-password-file ~/.vault_pass.txt
```

**Credentials used:**
- `vault_mysql_root_password` from encrypted vault ✅

---

### **Scenario 2: CI/CD Pipeline**

```bash
# Set environment variables in CI/CD system
export MYSQL_ROOT_PASSWORD="ci_password"
export MYSQL_PETCLINIC_PASSWORD="ci_petclinic_pass"

# Run playbook (no vault file needed)
ansible-playbook playbooks/mysql.yml
```

**Credentials used:**
- Environment variables ✅
- Vault file ignored (not present or env var takes precedence)

---

### **Scenario 3: Local Development (Quick Testing)**

```bash
# Don't set vault or environment variables
# Run playbook
ansible-playbook playbooks/mysql.yml
```

**Credentials used:**
- Hardcoded defaults (`Petclinic@2024`, `petclinic123`, etc.) ✅
- ⚠️ **FOR DEVELOPMENT ONLY**

---

## 🔐 Security Best Practices

### **1. Never Commit Unencrypted Vault Files**

Add to `.gitignore`:
```
# Unencrypted vault files
group_vars/vault.yml.bak
group_vars/**/*vault*.yml.decrypted
.vault_pass.txt
*.vault_pass
```

### **2. Secure Your Vault Password**

```bash
# Create vault password file
echo "YourSecureVaultPassword" > ~/.vault_pass.txt

# Set restrictive permissions
chmod 600 ~/.vault_pass.txt

# NEVER commit this file to git!
```

### **3. Use Different Passwords Per Environment**

```
group_vars/
├── production/
│   └── vault.yml          # Production passwords
├── staging/
│   └── vault.yml          # Staging passwords  
└── development/
    └── vault.yml          # Dev passwords
```

### **4. Rotate Credentials Regularly**

```bash
# 1. Edit vault
ansible-vault edit group_vars/vault.yml

# 2. Update passwords

# 3. Re-run playbooks to update systems
ansible-playbook playbooks/mysql.yml --tags mysql
```

### **5. Use Strong Vault Passwords**

✅ **Good:** `My$ecure!V@ult#P@ssw0rd2024`  
❌ **Bad:** `password123`

Generate strong passwords:
```bash
# Generate a random vault password
openssl rand -base64 32
```

---

## 🔍 Verification

### **Check if Vault is Encrypted**
```bash
cat group_vars/vault.yml

# If encrypted, you'll see:
# $ANSIBLE_VAULT;1.1;AES256
# 343934393...
```

### **Verify Variables Are Being Used**
```bash
# Check what password will be used
ansible mysql -m debug -a "var=mysql_root_password"

# With vault:
# "mysql_root_password": "MySuperSecureRootPassword123!"

# Without vault or env:
# "mysql_root_password": "Petclinic@2024"
```

### **Test Vault Decryption**
```bash
# View decrypted contents
ansible-vault view group_vars/vault.yml
```

---

## 📊 Comparison: Current vs Production Setup

### **Current Setup (Default - Development)**
```yaml
mysql_root_password: "Petclinic@2024"
```
- ⚠️ Visible in plain text
- ⚠️ Exposed in version control
- ✅ Easy for development

### **With Vault (Production)**
```yaml
# group_vars/vault.yml (encrypted)
vault_mysql_root_password: "MySuperSecurePassword123!"

# group_vars/mysql.yml (references vault)
mysql_root_password: "{{ vault_mysql_root_password }}"
```
- ✅ Encrypted at rest
- ✅ Safe for version control
- ✅ Production-ready

---

## 🚨 Troubleshooting

### **Error: "Vault is not encrypted"**
```bash
# Encrypt the file
ansible-vault encrypt group_vars/vault.yml
```

### **Error: "Vault password required"**
```bash
# Provide vault password
ansible-playbook playbooks/mysql.yml --ask-vault-pass

# Or use password file
ansible-playbook playbooks/mysql.yml --vault-password-file ~/.vault_pass.txt
```

### **Error: "Variable 'vault_mysql_root_password' is undefined"**

Two options:

**Option A:** Encrypt your vault file
```bash
ansible-vault encrypt group_vars/vault.yml
```

**Option B:** Use environment variables or let it fall back to defaults
```bash
export MYSQL_ROOT_PASSWORD="your_password"
ansible-playbook playbooks/mysql.yml
```

---

## 🎯 Recommended Workflow

### **For Production:**

1. **Initial Setup:**
   ```bash
   # Create vault password
   echo "SecureVaultPassword" > ~/.vault_pass.txt
   chmod 600 ~/.vault_pass.txt
   
   # Edit vault file
   ansible-vault edit group_vars/vault.yml
   # Add your production passwords
   ```

2. **Update ansible.cfg:**
   ```ini
   [defaults]
   vault_password_file = ~/.vault_pass.txt
   ```

3. **Run playbooks:**
   ```bash
   ansible-playbook playbooks/site.yml
   ```

### **For Development:**

1. **No vault needed:**
   ```bash
   # Just run playbooks, uses defaults
   ansible-playbook playbooks/mysql.yml
   ```

2. **Or use environment variables:**
   ```bash
   export MYSQL_ROOT_PASSWORD="dev_password"
   ansible-playbook playbooks/mysql.yml
   ```

---

## 📝 Summary

**You now have 3 ways to manage credentials:**

| Method | Use Case | Priority | Security |
|--------|----------|----------|----------|
| **Ansible Vault** | Production | Highest (1) | 🔒 Encrypted |
| **Environment Variables** | CI/CD | Medium (2) | 🔐 Isolated |
| **Hardcoded Defaults** | Development | Lowest (3) | ⚠️ Exposed |

**For production deployment:**
```bash
# 1. Set up vault
ansible-vault encrypt group_vars/vault.yml

# 2. Deploy
ansible-playbook playbooks/site.yml --vault-password-file ~/.vault_pass.txt
```

**For development:**
```bash
# Just run (uses defaults)
ansible-playbook playbooks/mysql.yml
```

---

## 🔗 Additional Resources

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Managing Secrets with Ansible Vault](https://www.ansible.com/blog/tag/vault)

---

**Created:** 2024-12-04  
**Purpose:** Secure credential management for Spring Petclinic Infrastructure  
**Encryption:** AES256
