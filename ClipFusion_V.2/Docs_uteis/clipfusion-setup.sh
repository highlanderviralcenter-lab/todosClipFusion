#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

[ "$EUID" -ne 0 ] && echo -e "${RED}Execute como root${NC}" && exit 1

ok()  { echo -e "  ${GREEN}✅${NC} $1"; }
fix() { echo -e "  ${BLUE}🔧${NC} $1"; }

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║        CLIPFUSION SETUP - DEBIAN TUNADO 3.0 (SEM DOCKER/PG)      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 1. PACOTES${NC}"

apt-get update -qq
apt-get install -y \
    firmware-misc-nonfree \
    intel-microcode \
    intel-media-va-driver-non-free \
    i965-va-driver-shaders \
    vainfo \
    intel-gpu-tools \
    ffmpeg \
    thermald \
    linux-cpupower \
    powertop \
    btrfs-progs \
    msr-tools \
    lm-sensors \
    htop btop \
    curl wget git vim neofetch \
    zram-tools \
    xorg i3-wm i3status i3lock \
    lightdm lightdm-gtk-greeter \
    fonts-noto fonts-noto-color-emoji fonts-firacode \
    rxvt-unicode rofi feh \
    firefox-esr thunar \
    openssh-server

ok "Pacotes instalados"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 2. GRUPOS DO USUÁRIO${NC}"

getent group render >/dev/null || groupadd render
usermod -aG video,render highlander
ok "highlander nos grupos video e render"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 3. NVIDIA BLOQUEADA${NC}"

cat > /etc/modprobe.d/blacklist-nvidia.conf <<'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
options nouveau modeset=0
EOF

update-initramfs -u
ok "blacklist-nvidia.conf criado + initramfs atualizado"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 4. GRUB${NC}"

GRUB_LINE='GRUB_CMDLINE_LINUX_DEFAULT="quiet mitigations=off intel_pstate=active intel_pstate.max_perf_pct=100 i915.enable_guc=3 i915.enable_fbc=1 i915.enable_psr=0 i915.fastboot=1 i915.modeset=1 modprobe.blacklist=nouveau,nvidia,nvidia_drm,nvidia_modeset processor.max_cstate=5 intel_iommu=on iommu=pt nmi_watchdog=0 nowatchdog tsc=reliable clocksource=tsc hpet=disable audit=0"'

if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|${GRUB_LINE}|" /etc/default/grub
else
    echo "$GRUB_LINE" >> /etc/default/grub
fi

update-grub
ok "GRUB configurado"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 5. VA-API — /etc/environment${NC}"

cat > /etc/environment <<'EOF'
LIBVA_DRIVER_NAME=iHD
LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
EOF

ok "/etc/environment configurado"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 6. ZRAM${NC}"

cat > /etc/default/zramswap <<'EOF'
ALGO=zstd
SIZE=4096
PRIORITY=100
EOF

systemctl enable --now zramswap
ok "ZRAM configurado: zstd, 4GB, prioridade 100"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 7. SWAPFILE SSD${NC}"

if [ ! -f /swap/swapfile ]; then
    mkdir -p /swap
    chattr +C /swap
    fix "Criando swapfile 2GB (dd — pode demorar ~30s)"
    dd if=/dev/zero of=/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /swap/swapfile
    mkswap /swap/swapfile
    swapon -p 50 /swap/swapfile
    grep -q '/swap/swapfile' /etc/fstab || \
        echo '/swap/swapfile none swap sw,pri=50 0 0' >> /etc/fstab
else
    fix "swapfile já existe — verificando se está ativo"
    swapon --show | grep -q '/swap/swapfile' || swapon -p 50 /swap/swapfile
fi

ok "Swapfile 2GB ativo (prioridade 50)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 8. SYSCTL${NC}"

cat > /etc/sysctl.d/99-performance.conf <<'EOF'
# === SCHEDULER (2c/4t i5-6200U) ===
# Não expostos neste kernel:
# kernel.sched_migration_cost_ns=5000000
# kernel.sched_min_granularity_ns=2000000
# kernel.sched_wakeup_granularity_ns=3000000
# kernel.sched_latency_ns=12000000
kernel.sched_autogroup_enabled=1

# === MEMÓRIA ===
vm.swappiness=150
vm.vfs_cache_pressure=50
vm.dirty_ratio=30
vm.dirty_background_ratio=10
vm.dirty_expire_centisecs=1000
vm.dirty_writeback_centisecs=500
vm.min_free_kbytes=131072
vm.overcommit_memory=2
vm.overcommit_ratio=80

# === NETWORK ===
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0

# === FILESYSTEM ===
fs.inotify.max_user_watches=1048576
fs.file-max=2097152
fs.aio-max-nr=524288
EOF

sysctl -p /etc/sysctl.d/99-performance.conf >/dev/null
ok "sysctl aplicado"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 9. MSR / MÓDULOS${NC}"

grep -qxF 'msr' /etc/modules || echo 'msr' >> /etc/modules
modprobe msr
ok "msr configurado"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 10. TDP UNLOCK${NC}"

cat > /usr/local/bin/tdp-unlock.sh <<'EOF'
#!/bin/bash
[ "$EUID" -ne 0 ] && echo 'Execute como root' && exit 1
modprobe msr
wrmsr -a 0x610 0x00dc8004dc8000
wrmsr -a 0x1ad 0x1B1B1B1B1B1B1B1B
wrmsr -a 0x618 0x0
echo "TDP unlocked: PL1=20W, PL2=25W, Turbo=2.7GHz (i5-6200U)"
EOF
chmod +x /usr/local/bin/tdp-unlock.sh

cat > /etc/systemd/system/tdp-unlock.service <<'EOF'
[Unit]
Description=TDP Unlock i5-6200U
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tdp-unlock.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ok "tdp-unlock.sh e service criados"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 11. CPUPOWER / THERMALD / FSTRIM / SSH / LIGHTDM${NC}"

echo 'GOVERNOR="performance"' > /etc/default/cpupower
cpupower frequency-set -g performance >/dev/null 2>&1 || true

systemctl daemon-reload
systemctl enable --now thermald cpupower tdp-unlock.service lightdm fstrim.timer ssh
ok "Serviços habilitados: thermald, cpupower, tdp-unlock, lightdm, fstrim, ssh"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 12. i3 CONFIG${NC}"

mkdir -p /home/highlander/.config/i3
cp -f /etc/i3/config /home/highlander/.config/i3/config

cat >> /home/highlander/.config/i3/config <<'EOF'

# ClipFusion tuning
gaps inner 0
gaps outer 0
default_border pixel 1

bindsym $mod+Shift+m exec urxvt -e btop
bindsym $mod+Shift+g exec urxvt -e intel_gpu_top
bindsym $mod+b exec firefox-esr

assign [class="clipfusion"] workspace 4:render
EOF

chown -R highlander:highlander /home/highlander/.config/i3
ok "i3 config configurado"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 13. SCRIPTS${NC}"

cat > /usr/local/bin/monitor-system.sh <<'EOF'
#!/bin/bash
watch -n 2 '
echo "CPU:"; grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2
echo
echo "TEMP:"; sensors 2>/dev/null | grep -E "Core 0|Package id 0" || true
echo
echo "MEM:"; free -h
echo
echo "SWAP:"; swapon --show
echo
echo "GPU:"; command -v intel_gpu_top >/dev/null && echo "intel_gpu_top disponível" || echo "intel_gpu_top ausente"
'
EOF
chmod +x /usr/local/bin/monitor-system.sh

cat > /usr/local/bin/snapshot-weekly.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M)
KEEP=7
btrfs subvolume snapshot -r / /.snapshots/root-$DATE
btrfs subvolume snapshot -r /home /.snapshots/home-$DATE
echo "$(date): Snapshot $DATE criado" >> /var/log/snapshots.log
ls -t /.snapshots/root-* 2>/dev/null | tail -n +$(($KEEP+1)) | xargs -r btrfs subvolume delete
ls -t /.snapshots/home-* 2>/dev/null | tail -n +$(($KEEP+1)) | xargs -r btrfs subvolume delete
journalctl --vacuum-time=7d
EOF
chmod +x /usr/local/bin/snapshot-weekly.sh

CRON_LINE='0 3 * * 0 /usr/local/bin/snapshot-weekly.sh'
crontab -l 2>/dev/null | grep -Fqx "$CRON_LINE" || \
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -

ok "monitor-system.sh, snapshot-weekly.sh e crontab configurados"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}▶ 14. BASHRC — aliases e exports${NC}"

BASHRC=/home/highlander/.bashrc

add_bashrc() {
    grep -qF "$1" "$BASHRC" 2>/dev/null || echo "$1" >> "$BASHRC"
}

add_bashrc "alias ll='ls -lah'"
add_bashrc "alias update='sudo apt update && sudo apt upgrade -y'"
add_bashrc "alias temps='sensors | grep Core'"
add_bashrc "alias validate='sudo /usr/local/bin/validate-system.sh'"
add_bashrc "alias monitor='sudo /usr/local/bin/monitor-system.sh'"
add_bashrc "alias snapshot='sudo /usr/local/bin/snapshot-weekly.sh'"
add_bashrc "export LIBVA_DRIVER_NAME=iHD"
add_bashrc "export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri"

chown highlander:highlander "$BASHRC"
ok "aliases e exports configurados"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ SETUP COMPLETO${NC}"
echo ""
echo "  Próximos passos:"
echo "  1. reboot  (para GRUB + initramfs entrarem em vigor)"
echo "  2. bash clipfusion-check-final.sh  (confirmar tudo verde)"
echo "════════════════════════════════════════════════════════════════════"
