apt update && apt install -y \
  intel-media-va-driver-non-free \
  i965-va-driver-shaders \
  ffmpeg \
  xorg i3-wm i3status i3lock \
  lightdm lightdm-gtk-greeter \
  fonts-noto fonts-noto-color-emoji fonts-firacode \
  rxvt-unicode rofi feh \
  firefox-esr neofetch thunar \
  thermald linux-cpupower msr-tools

getent group render >/dev/null || groupadd render
usermod -aG video,render highlander

grep -qxF 'msr' /etc/modules || echo 'msr' >> /etc/modules
modprobe msr

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

cat > /etc/environment <<'EOF'
LIBVA_DRIVER_NAME=iHD
LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
EOF

cat > /etc/sysctl.d/99-performance.conf <<'EOF'
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=1
vm.swappiness=150
vm.vfs_cache_pressure=50
vm.dirty_ratio=30
vm.dirty_background_ratio=10
vm.dirty_expire_centisecs=1000
vm.dirty_writeback_centisecs=500
vm.min_free_kbytes=131072
vm.overcommit_memory=2
vm.overcommit_ratio=80
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
fs.inotify.max_user_watches=1048576
fs.file-max=2097152
fs.aio-max-nr=524288
EOF
sysctl -p /etc/sysctl.d/99-performance.conf

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

echo 'GOVERNOR="performance"' > /etc/default/cpupower
systemctl enable --now thermald cpupower tdp-unlock.service lightdm fstrim.timer

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

crontab -l 2>/dev/null | { cat; echo '0 3 * * 0 /usr/local/bin/snapshot-weekly.sh'; } | crontab -

grep -q "alias ll='ls -lah'" /home/highlander/.bashrc || cat >> /home/highlander/.bashrc <<'EOF'

alias ll='ls -lah'
alias update='sudo apt update && sudo apt upgrade -y'
alias temps='sensors | grep Core'
alias validate='sudo /usr/local/bin/validate-system.sh'
alias monitor='sudo /usr/local/bin/monitor-system.sh'
alias snapshot='sudo /usr/local/bin/snapshot-weekly.sh'
export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
EOF

chown highlander:highlander /home/highlander/.bashrc
