# EC2 Volume Resize - Quick Start

## ✅ What I've Done

1. **Updated EC2 Module** - Added `root_block_device` configuration
2. **Added Variables** - `root_volume_size` (default: 20 GB) and `root_volume_type` (default: gp3)
3. **Created Guide** - Comprehensive guide at `terraform/EC2_VOLUME_RESIZE_GUIDE.md`

## 🚀 Quick Commands

### Option 1: Resize Existing Volumes (No Downtime)

```bash
# Get volume IDs
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=K8s-Master-Server" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text

# Resize volume (replace vol-xxxxx)
aws ec2 modify-volume --volume-id vol-xxxxx --size 40

# SSH to instance and extend filesystem
ssh -i your-key.pem ec2-user@<instance-ip>
sudo growpart /dev/nvme0n1 1
sudo xfs_growfs /
df -h /
```

### Option 2: Update Terraform for Future Deployments

Add to your instance modules in `terraform/app/main.tf`:

```hcl
module "k8s_master_instance" {
  # ... existing config ...
  root_volume_size = 40  # 40 GB
  root_volume_type = "gp3"
}

module "K8s_worker_instance" {
  # ... existing config ...
  root_volume_size = 40  # 40 GB
  root_volume_type = "gp3"
}
```

## 📋 Recommended Sizes

- **K8s Master**: 40 GB
- **K8s Worker**: 40 GB
- **Jenkins**: 30 GB
- **Others**: 20 GB

## 💰 Cost Impact

- 20 GB gp3: $1.60/month
- 40 GB gp3: $3.20/month
- Increase: ~$1.60/month per instance

## ⚠️ Important

- Terraform changes will **recreate instances** (data loss)
- AWS CLI resize is **live** (no downtime)
- Use AWS CLI for existing instances, Terraform for new ones

See `EC2_VOLUME_RESIZE_GUIDE.md` for complete details.
