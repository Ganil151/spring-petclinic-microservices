#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# Worker Node Bootstrap — User Data (First Boot Only)
# ───────────────────────────────────────────────────────────────────
# PURPOSE: Handle disk provisioning and hostname — things that MUST
#          happen at first boot before Ansible can connect.
# NOTE:    Java, Maven, Docker, AWS CLI, Kubectl, Helm are installed
#          by Ansible roles. Do NOT duplicate those here.
# ───────────────────────────────────────────────────────────────────
set -e

# ─── 1. Initialization ───────────────────────────────────────────
sudo hostnamectl set-hostname worker-node
echo "Stabilizing instance for 60 seconds..."
sleep 60

# ─── 2. Advanced Disk Management (AL2023 / NVMe Aware) ──────────
echo "Configuring Extra Storage..."
# Modern AWS instances use NVMe; /dev/sdb is often /dev/nvme1n1
DISK_DEVICE=$(lsblk -dpno NAME | grep -E 'nvme[1-9]n1|sdb' | head -n 1)
MOUNT_POINT="/mnt/data"

if [ -n "$DISK_DEVICE" ]; then
    echo "Found device: $DISK_DEVICE"
    # Format if no filesystem exists
    if ! sudo blkid "$DISK_DEVICE" >/dev/null 2>&1; then
        sudo mkfs -t xfs "$DISK_DEVICE"
    fi

    sudo mkdir -p "$MOUNT_POINT"

    # Get UUID for stable fstab (Best Practice)
    UUID=$(sudo blkid -s UUID -o value "$DISK_DEVICE")

    if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
        echo "UUID=$UUID $MOUNT_POINT xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
        sudo mount -a
    fi
    sudo chown -R ec2-user:ec2-user "$MOUNT_POINT"
else
    echo "WARNING: No extra disk found. Proceeding with root partition (Not recommended for Prod)."
fi

# ─── 3. Minimal System Update ────────────────────────────────────
# Only install packages NOT handled by Ansible roles
echo "Updating system and installing base dependencies..."
sudo dnf update -y
sudo dnf install -y fontconfig git python3 python3-pip jq

# ─── 4. Prepare Docker Data Root (if extra disk mounted) ────────
# Pre-create the Docker config so Ansible's docker role uses the
# right data-root when it starts the service.
if mountpoint -q "$MOUNT_POINT"; then
    sudo mkdir -p "$MOUNT_POINT/docker"
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "data-root": "$MOUNT_POINT/docker",
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
fi

# ─── 5. Verification ─────────────────────────────────────────────
echo "────────────────────────────────────────────────"
echo "✅ Worker Node Bootstrap Complete!"
echo "────────────────────────────────────────────────"
printf "Hostname:        %s\n" "$(hostname)"
printf "Storage:         %s\n" "$(df -h $MOUNT_POINT 2>/dev/null || df -h / | tail -1)"
echo "NOTE: Java, Maven, Docker, AWS CLI, Kubectl,"
echo "      Helm will be installed by Ansible."
echo "────────────────────────────────────────────────"