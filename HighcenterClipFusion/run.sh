#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

configure_zram() {
  if ! command -v zramctl >/dev/null 2>&1; then
    echo "[HCF] zramctl não encontrado, pulando zRAM"
    return 0
  fi

  if [[ ! -e /sys/block/zram0 && ! -w /sys/class/zram-control/hot_add ]]; then
    echo "[HCF] Sem acesso ao kernel zRAM neste ambiente, pulando"
    return 0
  fi

  local mem_kb zram_bytes ok=1
  mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  zram_bytes=$((mem_kb * 1024 * 75 / 100))

  command -v modprobe >/dev/null 2>&1 && sudo modprobe zram num_devices=1 || ok=0
  [[ -w /sys/block/zram0/comp_algorithm ]] && echo lz4 | sudo tee /sys/block/zram0/comp_algorithm >/dev/null || ok=0
  [[ -w /sys/block/zram0/disksize ]] && echo "$zram_bytes" | sudo tee /sys/block/zram0/disksize >/dev/null || ok=0
  sudo mkswap /dev/zram0 >/dev/null 2>&1 || ok=0
  sudo swapon -p 100 /dev/zram0 || ok=0

  if [[ "$ok" -eq 1 ]]; then
    echo "[HCF] zRAM configurado (75% RAM, lz4)"
  else
    echo "[HCF] zRAM parcialmente indisponível neste ambiente"
  fi
}

ensure_i915_guc_hint() {
  local hint_file
  hint_file="$ROOT_DIR/.kernel_hint_i915_enable_guc"
  if ! grep -q 'i915.enable_guc=3' /proc/cmdline; then
    cat > "$hint_file" <<EOF
Para aceleração total Intel HD 520, adicione ao kernel cmdline:
  i915.enable_guc=3
Exemplo (GRUB):
  GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_guc=3"
Depois execute: sudo update-grub && reboot
EOF
    echo "[HCF] Aviso salvo em $hint_file"
  fi
}

python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip >/dev/null
pip install -r requirements.txt >/dev/null

configure_zram
ensure_i915_guc_hint

exec python main_gui.py "$@"
