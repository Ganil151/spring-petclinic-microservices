#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# Worker Node Bootstrap — User Data (Bare Minimum)
# ───────────────────────────────────────────────────────────────────
# PURPOSE: Disk provisioning & hostname — things that MUST
#          happen at first boot before Ansible can connect.
# ALL tool installations are handled by Ansible roles.
# ───────────────────────────────────────────────────────────────────
set -e

# ─── 1. Set Hostname ─────────────────────────────────────────────
sudo hostnamectl set-hostname worker-node

# ─── 2. Wait for Cloud-Init to Finish ────────────────────────────
echo "Waiting for instance stabilization..."
sleep 30

# ─── 3. Advanced Disk Management (AL2023 / NVMe Aware) ──────────
echo "Configuring Extra Storage..."
DISK_DEVICE=$(lsblk -dpno NAME | grep -E 'nvme[1-9]n1|sdb' | head -n 1)
MOUNT_POINT="/mnt/data"

if [ -n "$DISK_DEVICE" ]; then
    echo "Found device: $DISK_DEVICE"
    if ! sudo blkid "$DISK_DEVICE" >/dev/null 2>&1; then
        sudo mkfs -t xfs "$DISK_DEVICE"
    fi

    sudo mkdir -p "$MOUNT_POINT"
    UUID=$(sudo blkid -s UUID -o value "$DISK_DEVICE")

    if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
        echo "UUID=$UUID $MOUNT_POINT xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
        sudo mount -a
    fi
    sudo chown -R ec2-user:ec2-user "$MOUNT_POINT"

    # Pre-configure Docker data-root for extra volume
    sudo mkdir -p "$MOUNT_POINT/docker" /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "data-root": "$MOUNT_POINT/docker",
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
else
    echo "WARNING: No extra disk found. Using root partition."
fi

# ─── 4. System Update & SSH Dependencies ─────────────────────────
sudo dnf update -y
sudo dnf install -y python3 python3-pip

echo "✅ Bootstrap complete. Ready for Ansible configuration."