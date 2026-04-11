#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

USER_NAME="highlander"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6 || true)"

[ "$EUID" -ne 0 ] && echo -e "${RED}Execute como root${NC}" && exit 1
[ -z "$USER_HOME" ] && echo -e "${RED}Usuário ${USER_NAME} não encontrado${NC}" && exit 1

ok()   { echo -e "  ${GREEN}✅${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
fix()  { echo -e "  ${BLUE}🔧${NC} $1"; }

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         CLIPFUSION FIX - DEBIAN TUNADO 3.0 (SEM DOCKER/PG)       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"

echo ""
echo -e "${BLUE}▶ 1. HARDWARE${NC}"

RAM_MB="$(free -m | awk '/^Mem:/{print $2}')"
if [ "${RAM_MB:-0}" -ge 7500 ]; then
    ok "RAM >= 7.5GB (${RAM_MB}MB)"
else
    warn "RAM ${RAM_MB}MB detectada — abaixo de 7.5GB. Hardware, sem fix via script."
fi

echo ""
echo -e "${BLUE}▶ 2. PACOTES (VA-API + i3 + ffmpeg)${NC}"

MISSING_PKGS=""
for pkg in \
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
    htop \
    btop \
    curl \
    wget \
    git \
    vim \
    neofetch \
    zram-tools \
    xorg \
    i3-wm \
    i3status \
    i3lock \
    lightdm \
    lightdm-gtk-greeter \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-firacode \
    rxvt-unicode \
    rofi \
    feh \
    firefox-esr \
    thunar \
    openssh-server; do
    dpkg -s "$pkg" >/dev/null 2>&1 || MISSING_PKGS="$MISSING_PKGS $pkg"
done

if [ -n "$MISSING_PKGS" ]; then
    fix "Instalando:$MISSING_PKGS"
    apt-get update -qq
    apt-get install -y $MISSING_PKGS
    ok "Pacotes instalados"
else
    ok "Todos os pacotes já instalados"
fi

echo ""
echo -e "${BLUE}▶ 3. GRUPOS DO USUÁRIO${NC}"

getent group render >/dev/null || groupadd render
usermod -aG video,render "$USER_NAME" || true
ok "${USER_NAME} nos grupos video e render"

echo ""
echo -e "${BLUE}▶ 4. VA-API — /etc/environment${NC}"

touch /etc/environment

grep -q '^LIBVA_DRIVER_NAME=' /etc/environment 2>/dev/null \
    && sed -i 's|^LIBVA_DRIVER_NAME=.*|LIBVA_DRIVER_NAME=iHD|' /etc/environment \
    || echo 'LIBVA_DRIVER_NAME=iHD' >> /etc/environment

grep -q '^LIBVA_DRIVERS_PATH=' /etc/environment 2>/dev/null \
    && sed -i 's|^LIBVA_DRIVERS_PATH=.*|LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri|' /etc/environment \
    || echo 'LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri' >> /etc/environment

ok "/etc/environment ajustado sem sobrescrever o restante"

echo ""
echo -e "${BLUE}▶ 5. NVIDIA BLOQUEADA${NC}"

cat > /etc/modprobe.d/blacklist-nvidia.conf <<'EOT'
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
options nouveau modeset=0
EOT

update-initramfs -u
ok "blacklist-nvidia.conf criado + initramfs atualizado"

echo ""
echo -e "${BLUE}▶ 6. SYSCTL${NC}"

SYSCTL_FILE=/etc/sysctl.d/99-performance.conf

cat > "$SYSCTL_FILE" <<'EOT'
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
EOT

sysctl -p "$SYSCTL_FILE" >/dev/null 2>&1
ok "sysctl aplicado"

echo ""
echo -e "${BLUE}▶ 7. MSR / MÓDULOS${NC}"

touch /etc/modules
grep -qxF 'msr' /etc/modules || echo 'msr' >> /etc/modules
modprobe msr 2>/dev/null || true
ok "msr configurado"

echo ""
echo -e "${BLUE}▶ 8. TDP UNLOCK${NC}"

cat > /usr/local/bin/tdp-unlock.sh <<'EOT'
#!/bin/bash
[ "$EUID" -ne 0 ] && echo 'Execute como root' && exit 1
modprobe msr
wrmsr -a 0x610 0x00dc8004dc8000
wrmsr -a 0x1ad 0x1B1B1B1B1B1B1B1B
wrmsr -a 0x618 0x0
echo "TDP unlocked: PL1=20W, PL2=25W, Turbo=2.7GHz (i5-6200U)"
EOT
chmod +x /usr/local/bin/tdp-unlock.sh

cat > /etc/systemd/system/tdp-unlock.service <<'EOT'
[Unit]
Description=TDP Unlock i5-6200U
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tdp-unlock.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable --now tdp-unlock.service 2>/dev/null || true
ok "tdp-unlock.sh e service configurados"

echo ""
echo -e "${BLUE}▶ 9. CPUPOWER / THERMALD / FSTRIM / SSH / LIGHTDM${NC}"

echo 'GOVERNOR="performance"' > /etc/default/cpupower
systemctl enable --now thermald 2>/dev/null || true
systemctl enable --now cpupower 2>/dev/null || true
systemctl enable --now fstrim.timer 2>/dev/null || true
systemctl enable --now lightdm 2>/dev/null || true
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || true
cpupower frequency-set -g performance >/dev/null 2>&1 || true

systemctl is-active thermald >/dev/null 2>&1 && ok "thermald ativo" || warn "thermald não confirmou ativo"
systemctl is-active cpupower >/dev/null 2>&1 && ok "cpupower ativo" || warn "cpupower não confirmou ativo"
systemctl is-enabled fstrim.timer >/dev/null 2>&1 && ok "fstrim.timer habilitado" || warn "fstrim.timer não confirmou habilitado"
systemctl is-enabled lightdm >/dev/null 2>&1 && ok "lightdm habilitado" || warn "lightdm não confirmou habilitado"
(systemctl is-active ssh >/dev/null 2>&1 || systemctl is-active sshd >/dev/null 2>&1) && ok "SSH ativo" || warn "SSH não confirmou ativo"

echo ""
echo -e "${BLUE}▶ 10. i3 CONFIG${NC}"

mkdir -p "${USER_HOME}/.config/i3"
I3CFG="${USER_HOME}/.config/i3/config"

if [ ! -f "$I3CFG" ]; then
    cp /etc/i3/config "$I3CFG"
fi

if ! grep -q '^# ClipFusion tuning$' "$I3CFG" 2>/dev/null; then
cat >> "$I3CFG" <<'EOT'

# ClipFusion tuning
gaps inner 0
gaps outer 0
default_border pixel 1
bindsym $mod+Shift+m exec urxvt -e btop
bindsym $mod+Shift+g exec urxvt -e intel_gpu_top
bindsym $mod+b exec firefox-esr
assign [class="clipfusion"] workspace 4:render
EOT
fi

chown -R "$USER_NAME:$USER_NAME" "${USER_HOME}/.config"
ok "i3 config configurado"

echo ""
echo -e "${BLUE}▶ 11. SCRIPTS${NC}"

cat > /usr/local/bin/monitor-system.sh <<'EOT'
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
EOT
chmod +x /usr/local/bin/monitor-system.sh
ok "monitor-system.sh criado"

cat > /usr/local/bin/snapshot-weekly.sh <<'EOT'
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M)
KEEP=7
btrfs subvolume snapshot -r / /.snapshots/root-$DATE
btrfs subvolume snapshot -r /home /.snapshots/home-$DATE
echo "$(date): Snapshot $DATE criado" >> /var/log/snapshots.log
ls -t /.snapshots/root-* 2>/dev/null | tail -n +$(($KEEP+1)) | xargs -r btrfs subvolume delete
ls -t /.snapshots/home-* 2>/dev/null | tail -n +$(($KEEP+1)) | xargs -r btrfs subvolume delete
journalctl --vacuum-time=7d
EOT
chmod +x /usr/local/bin/snapshot-weekly.sh
ok "snapshot-weekly.sh criado"

CRON_LINE='0 3 * * 0 /usr/local/bin/snapshot-weekly.sh'
crontab -l 2>/dev/null | grep -Fqx "$CRON_LINE" || {
    fix "Adicionando crontab semanal"
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
}
ok "Crontab configurado"

echo ""
echo -e "${BLUE}▶ 12. INSTALANDO CHECKER EM /usr/local/bin${NC}"

CHECKER_SRC=""
for candidate in \
    "${USER_HOME}/Downloads/clipfusion-check-final.sh" \
    "${USER_HOME}/clipfusion-check-final.sh" \
    "/root/clipfusion-check-final.sh"; do
    [ -f "$candidate" ] && CHECKER_SRC="$candidate" && break
done

if [ -n "$CHECKER_SRC" ]; then
    install -m 755 "$CHECKER_SRC" /usr/local/bin/validate-system.sh
    install -m 755 "$CHECKER_SRC" /usr/local/bin/clipfusion-check.sh
    ok "Checker instalado em /usr/local/bin"
else
    warn "clipfusion-check-final.sh não encontrado — alias validate ficará pendente"
fi

echo ""
echo -e "${BLUE}▶ 13. BASHRC — aliases e exports${NC}"

BASHRC="${USER_HOME}/.bashrc"
touch "$BASHRC"

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

chown "$USER_NAME:$USER_NAME" "$BASHRC"
ok "aliases e exports configurados"

echo ""
echo -e "${BLUE}▶ 14. SMOKE TEST VA-API${NC}"

if command -v ffmpeg >/dev/null 2>&1 && [ -e /dev/dri/renderD128 ]; then
    fix "Rodando encode de teste VA-API (2s 720p)..."
    TMP_OUT=/tmp/clipfusion-vaapi-fix-test.mp4
    if LIBVA_DRIVER_NAME=iHD ffmpeg -hide_banner -y \
        -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
        -f lavfi -i testsrc=duration=2:size=1280x720:rate=30 \
        -vf 'format=nv12,hwupload' \
        -c:v h264_vaapi -b:v 3M \
        "$TMP_OUT" >/dev/null 2>&1; then
        ok "Smoke test VA-API passou"
        rm -f "$TMP_OUT"
    else
        warn "Smoke test VA-API falhou — pode precisar de reboot para carregar o driver iHD"
        rm -f "$TMP_OUT"
    fi
else
    warn "ffmpeg ou /dev/dri/renderD128 ausente — smoke test pulado"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ FIX COMPLETO — rode o clipfusion-check-final.sh para confirmar${NC}"
if [ "${RAM_MB:-0}" -lt 7500 ]; then
    echo -e "${YELLOW}⚠️  RAM abaixo de 7.5GB: único item sem fix via script${NC}"
fi
echo -e "${YELLOW}⚠️  Reboot recomendado para GRUB, initramfs e sessão gráfica${NC}"
echo "════════════════════════════════════════════════════════════════════"
