#!/usr/bin/env bash
set -euo pipefail

log() { echo "[ClipFusion] $*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERRO] comando ausente: $1"; exit 1; }
}

configure_grub_guc() {
  if ! grep -q "i915.enable_guc=3" /etc/default/grub; then
    log "Adicionando i915.enable_guc=3 no GRUB"
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_guc=3 /' /etc/default/grub
    sudo update-grub
    log "GRUB atualizado. Reinicie para aplicar o parâmetro de kernel."
  else
    log "i915.enable_guc=3 já configurado no GRUB"
  fi
}

pick_zram_algo() {
  if grep -q -w "lz4" /proc/crypto 2>/dev/null; then
    echo "lz4"
  else
    echo "zstd"
  fi
}

reset_zram_state() {
  # Evita conflito entre zramswap e systemd-zram-generator.
  sudo systemctl disable --now zramswap 2>/dev/null || true
  sudo systemctl disable --now systemd-zram-setup@zram0.service 2>/dev/null || true
  sudo swapoff /dev/zram0 2>/dev/null || true
}

setup_with_zramswap() {
  local algo="$1"
  log "Tentando configurar zRAM via zram-tools (zramswap)"
  sudo tee /etc/default/zramswap >/dev/null <<EOC
ALGO=${algo}
PERCENT=75
PRIORITY=100
EOC

  sudo systemctl daemon-reload
  sudo systemctl enable zramswap >/dev/null
  if sudo systemctl restart zramswap; then
    return 0
  fi
  return 1
}

setup_with_generator() {
  local algo="$1"
  log "Aplicando fallback via systemd-zram-generator (6144MiB)"
  sudo apt install -y systemd-zram-generator
  sudo tee /etc/systemd/zram-generator.conf >/dev/null <<EOC
[zram0]
zram-size = 6144MiB
compression-algorithm = ${algo}
swap-priority = 100
EOC

  sudo systemctl daemon-reload
  sudo systemctl restart systemd-zram-setup@zram0.service
}

validate_zram() {
  sudo swapon --show --noheadings 2>/dev/null | awk '{print $1}' | grep -q '/dev/zram0'
}

setup_swapfile() {
  local swapfile="/swap/swapfile"
  if [ ! -f "$swapfile" ]; then
    log "Criando swapfile em $swapfile"
    sudo mkdir -p /swap
    sudo fallocate -l 2G "$swapfile"
    sudo chmod 600 "$swapfile"
    sudo mkswap "$swapfile"
  fi

  if ! sudo swapon --show | awk '{print $1}' | grep -qx "$swapfile"; then
    sudo swapon "$swapfile"
  fi

  if ! grep -q "^$swapfile " /etc/fstab; then
    echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi
}

setup_sysctl() {
  sudo tee /etc/sysctl.d/99-clipfusion.conf >/dev/null <<'EOC'
sudo apt update
sudo apt install -y ffmpeg python3 python3-venv python3-pip zram-tools intel-media-va-driver-non-free mesa-va-drivers

if ! grep -q "i915.enable_guc=3" /etc/default/grub; then
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_guc=3 /' /etc/default/grub
  sudo update-grub
fi

ZRAM_ALGO="lz4"
if ! grep -q -w "lz4" /proc/crypto 2>/dev/null; then
  ZRAM_ALGO="zstd"
fi

# Debian zram-tools: use ALGO + PERCENT + PRIORITY (SIZE can break on some builds)
sudo tee /etc/default/zramswap >/dev/null <<EOF
ALGO=${ZRAM_ALGO}
PERCENT=75
PRIORITY=100
EOF

sudo systemctl daemon-reload || true
sudo systemctl enable zramswap
sudo systemctl restart zramswap
sudo systemctl --no-pager --full status zramswap || true

if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
fi

sudo tee /etc/sysctl.d/99-clipfusion.conf >/dev/null <<'EOF'
vm.swappiness=150
vm.dirty_ratio=30
EOC
  sudo sysctl --system >/dev/null
}

main() {
  require_cmd sudo
  require_cmd apt
  require_cmd systemctl
  require_cmd swapon

  log "Instalando dependências base"
  sudo apt update
  sudo apt install -y ffmpeg python3 python3-venv python3-pip zram-tools intel-media-va-driver-non-free mesa-va-drivers

  configure_grub_guc

  local algo
  algo="$(pick_zram_algo)"
  log "Algoritmo de compressão zRAM: ${algo}"

  reset_zram_state

  if setup_with_zramswap "$algo" && validate_zram; then
    log "zRAM ativo via zramswap"
  else
    log "zramswap falhou; coletando diagnóstico breve"
    sudo journalctl -u zramswap.service -n 20 --no-pager || true
    reset_zram_state
    setup_with_generator "$algo"
    if ! validate_zram; then
      echo "[ERRO] zRAM não foi ativado nem com fallback. Verifique: journalctl -xeu systemd-zram-setup@zram0.service"
      exit 1
    fi
    log "zRAM ativo via systemd-zram-generator"
  fi

  setup_swapfile
  setup_sysctl

  log "Resumo de swap ativo:"
  sudo swapon --show
}

main "$@"
