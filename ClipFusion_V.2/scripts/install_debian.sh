#!/usr/bin/env bash
set -euo pipefail
sudo apt update
sudo apt install -y ffmpeg python3 python3-venv python3-pip zram-tools intel-media-va-driver-non-free mesa-va-drivers

if ! grep -q "i915.enable_guc=3" /etc/default/grub; then
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_guc=3 /' /etc/default/grub
  sudo update-grub
fi

sudo tee /etc/default/zramswap >/dev/null <<'EOF'
ALGO=lz4
PERCENT=75
SIZE=6144
PRIORITY=100
EOF
sudo systemctl enable --now zramswap || true

if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
fi

sudo tee /etc/sysctl.d/99-clipfusion.conf >/dev/null <<'EOF'
vm.swappiness=150
vm.dirty_ratio=30
EOF
sudo sysctl --system
