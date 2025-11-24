# EC2 Volume Resize Guide - No GUI Required

## 🎯 Overview

This guide shows you how to safely increase EC2 instance volume size using **Terraform** and **AWS CLI** without touching the AWS Console GUI.

---

## 📋 **Current Situation**

Your EC2 instances are using the **default volume size** (8 GB for Amazon Linux 2023). For Kubernetes nodes, this is often insufficient.

**Recommended Sizes**:
- **K8s Master**: 30-50 GB
- **K8s Worker**: 30-50 GB
- **Jenkins Master**: 30 GB
- **Other instances**: 20 GB

---

## ✅ **Method 1: Using Terraform (Recommended)**

### **Step 1: Update EC2 Module**

Add `root_block_device` configuration to your EC2 module and expose it as a variable.

**File**: `terraform/MODULES/EC2/main.tf`

```hcl
resource "aws_instance" "master-server" {
  ami                         = var.ami
  key_name                    = var.key_name
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  # Root volume configuration
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = false
  }

  tags = {
    Name        = var.project_name_1
    Environment = var.environment
  }
}
```

### **Step 2: Add Variables to EC2 Module**

**File**: `terraform/MODULES/EC2/variables.tf`

```hcl
variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root volume (gp3, gp2, io1, etc.)"
  type        = string
  default     = "gp3"
}
```

### **Step 3: Update Main Terraform Config**

**File**: `terraform/app/main.tf`

```hcl
# K8s Master - Increase to 40 GB
module "k8s_master_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_5
  instance_type               = var.instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/k8s_master.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = 40  # NEW: 40 GB for K8s master
  root_volume_type            = "gp3"  # NEW: gp3 is faster and cheaper
}

# K8s Worker - Increase to 40 GB
module "K8s_worker_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_6
  instance_type               = var.instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/k8s_worker.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = 40  # NEW: 40 GB for K8s worker
  root_volume_type            = "gp3"  # NEW
}

# Jenkins Master - Increase to 30 GB
module "jenkins_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_1
  instance_type               = var.instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/master.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = 30  # NEW: 30 GB for Jenkins
  root_volume_type            = "gp3"  # NEW
}
```

### **Step 4: Apply Changes**

```bash
cd terraform/app

# Preview changes
terraform plan

# Apply changes (will recreate instances with new volume size)
terraform apply
```

> **⚠️ WARNING**: This will **recreate** your instances! All data will be lost unless you have backups or snapshots.

---

## 🔄 **Method 2: Resize Existing Volumes (No Downtime)**

If you want to resize **existing** instances without recreating them:

### **Step 1: Get Volume IDs**

```bash
# List all instances and their volumes
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],BlockDeviceMappings[0].Ebs.VolumeId]' \
  --output table
```

### **Step 2: Modify Volume Size**

```bash
# Resize a specific volume (replace vol-xxxxx with your volume ID)
aws ec2 modify-volume --volume-id vol-xxxxx --size 40

# Check modification status
aws ec2 describe-volumes-modifications --volume-ids vol-xxxxx
```

### **Step 3: Extend Filesystem on the Instance**

SSH into the instance and extend the filesystem:

```bash
# SSH to the instance
ssh -i your-key.pem ec2-user@<instance-ip>

# Check current disk usage
df -h

# Grow the partition (for Amazon Linux 2023)
sudo growpart /dev/nvme0n1 1

# Resize the filesystem
sudo xfs_growfs /

# Verify new size
df -h
```

### **Step 4: Automate for All Instances**

Create a script to resize all volumes:

```bash
#!/bin/bash
# resize-all-volumes.sh

VOLUME_SIZE=40  # New size in GB

# Get all volume IDs for your instances
VOLUME_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --query 'Reservations[*].Instances[*].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text)

for VOLUME_ID in $VOLUME_IDS; do
  echo "Resizing $VOLUME_ID to ${VOLUME_SIZE}GB..."
  aws ec2 modify-volume --volume-id $VOLUME_ID --size $VOLUME_SIZE
done

echo "All volumes resized. Wait 5 minutes, then extend filesystems on each instance."
```

---

## 🛠️ **Method 3: Using Terraform with Existing Instances**

To update Terraform to manage existing volumes without recreation:

### **Step 1: Import Existing Instances**

```bash
# Import existing instances into Terraform state
terraform import module.k8s_master_instance.aws_instance.master-server i-xxxxx
terraform import module.K8s_worker_instance.aws_instance.master-server i-yyyyy
```

### **Step 2: Update Terraform Config**

Add `root_block_device` to your EC2 module (as shown in Method 1).

### **Step 3: Use `lifecycle` to Prevent Replacement**

```hcl
resource "aws_instance" "master-server" {
  # ... existing config ...

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
  }

  lifecycle {
    ignore_changes = [
      root_block_device[0].volume_size  # Prevent recreation on size change
    ]
  }
}
```

### **Step 4: Manually Resize Volumes**

Use AWS CLI (Method 2) to resize volumes, then update Terraform config to match.

---

## 📊 **Comparison of Methods**

| Method | Downtime | Data Loss | Complexity | Best For |
|--------|----------|-----------|------------|----------|
| **Method 1: Terraform Recreate** | ✅ Yes | ✅ Yes | Low | New deployments |
| **Method 2: AWS CLI Resize** | ❌ No | ❌ No | Medium | Existing instances |
| **Method 3: Terraform Import** | ❌ No | ❌ No | High | Managing existing infra |

---

## 🎯 **Recommended Approach**

### **For Your Situation** (Existing K8s cluster):

1. **Use Method 2** (AWS CLI) to resize existing volumes without downtime
2. **Then update Terraform** (Method 1) for future deployments

### **Complete Workflow**:

```bash
# 1. Resize volumes via AWS CLI
aws ec2 modify-volume --volume-id vol-k8s-master --size 40
aws ec2 modify-volume --volume-id vol-k8s-worker --size 40

# 2. Wait for modification to complete (5 minutes)
aws ec2 describe-volumes-modifications --volume-ids vol-k8s-master vol-k8s-worker

# 3. SSH to each instance and extend filesystem
ssh k8s-master "sudo growpart /dev/nvme0n1 1 && sudo xfs_growfs /"
ssh k8s-worker "sudo growpart /dev/nvme0n1 1 && sudo xfs_growfs /"

# 4. Update Terraform for future deployments
# (Add root_block_device to EC2 module as shown in Method 1)

# 5. Verify
ssh k8s-master "df -h /"
ssh k8s-worker "df -h /"
```

---

## 🔍 **Verify Volume Resize**

### **Check from AWS CLI**:
```bash
aws ec2 describe-volumes --volume-ids vol-xxxxx \
  --query 'Volumes[0].[VolumeId,Size,State]' \
  --output table
```

### **Check from Instance**:
```bash
# Before resize
df -h /
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/nvme0n1p1  8.0G  4.5G  3.5G  57% /

# After resize
df -h /
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/nvme0n1p1   40G  4.5G   36G  12% /
```

---

## ⚠️ **Important Notes**

1. **Volume Modification Limits**: You can only modify a volume once every 6 hours
2. **Filesystem Type**: Amazon Linux 2023 uses XFS (use `xfs_growfs`), older versions use ext4 (use `resize2fs`)
3. **Backup First**: Always create snapshots before resizing
4. **Cost**: Larger volumes cost more (gp3: $0.08/GB/month)
5. **Performance**: gp3 is faster and cheaper than gp2

---

## 💰 **Cost Comparison**

| Volume Type | Size | Monthly Cost |
|-------------|------|--------------|
| gp3 8 GB | 8 GB | $0.64 |
| gp3 20 GB | 20 GB | $1.60 |
| gp3 40 GB | 40 GB | $3.20 |
| gp2 40 GB | 40 GB | $4.00 |

**Savings**: gp3 is 20% cheaper than gp2!

---

## 🚀 **Quick Commands Reference**

```bash
# List all volumes
aws ec2 describe-volumes --query 'Volumes[*].[VolumeId,Size,State,Tags[?Key==`Name`].Value|[0]]' --output table

# Resize volume
aws ec2 modify-volume --volume-id vol-xxxxx --size 40

# Check resize status
aws ec2 describe-volumes-modifications --volume-ids vol-xxxxx

# Extend partition (on instance)
sudo growpart /dev/nvme0n1 1

# Extend filesystem (on instance)
sudo xfs_growfs /  # For XFS (Amazon Linux 2023)
# OR
sudo resize2fs /dev/nvme0n1p1  # For ext4 (older systems)

# Verify
df -h /
```

---

## 📝 **Next Steps**

1. Decide which method to use based on your needs
2. Create snapshots of existing volumes (optional but recommended)
3. Resize volumes using chosen method
4. Update Terraform configuration for future deployments
5. Verify all instances have correct volume sizes

Need help with any specific step? Let me know!
