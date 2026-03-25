#!/usr/bin/env bash
# Debian Tunado 3.0 audit and checklist (ASCII only)
#
# Usage:
#   sudo ./audit_tunado3.sh
#   sudo ./audit_tunado3.sh --mode simple
#   sudo ./audit_tunado3.sh --mode full
#   sudo ./audit_tunado3.sh --fix
#
# Notes:
# - --fix applies only "safe" fixes (packages, services, blacklist file, zram config,
#   swapfile creation, sysctl file). It does NOT rewrite your GRUB cmdline automatically
#   and does NOT apply TDP unlock changes.
# - Docker config is validated (JSON must be valid, no // comments).

set -Eeuo pipefail

MODE="full"     # full expects all subvolumes; simple expects only @ and @home
DO_FIX=0

while [ $# -gt 0 ]; do
  case "$1" in
    --fix) DO_FIX=1; shift ;;
    --mode) MODE="${2:-full}"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    *) shift ;;
  esac
done

PASS=0
WARN=0
FAIL=0
SUG=()

pass() { echo "[OK]   $1"; PASS=$((PASS+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
info() { echo "[INFO] $1"; }
need() { SUG+=("$1"); }

have() { command -v "$1" >/dev/null 2>&1; }

require_root_for_fix() {
  if [ "$DO_FIX" -eq 1 ] && [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Run with sudo for --fix"
    exit 1
  fi
}

section() {
  echo ""
  echo "===================================================="
  echo "$1"
  echo "===================================================="
}

check_pkg() {
  local pkg="$1"
  local label="$2"
  if have dpkg-query && dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "installed"; then
    pass "$label"
  else
    warn "$label (missing package: $pkg)"
    need "Install: sudo apt install -y $pkg"
  fi
}

check_service_active() {
  local svc="$1"
  local label="$2"
  if have systemctl; then
    if systemctl is-active --quiet "$svc"; then
      pass "$label"
    else
      warn "$label (service inactive: $svc)"
      need "Enable: sudo systemctl enable --now $svc"
    fi
  else
    warn "$label (systemctl not available)"
  fi
}

check_service_enabled() {
  local svc="$1"
  local label="$2"
  if have systemctl; then
    if systemctl is-enabled --quiet "$svc"; then
      pass "$label"
    else
      warn "$label (not enabled: $svc)"
      need "Enable: sudo systemctl enable $svc"
    fi
  fi
}

check_cmdline_has() {
  local label="$1"
  local needle="$2"
  local sev="${3:-warn}"   # warn|fail

  if grep -q "$needle" /proc/cmdline 2>/dev/null; then
    pass "$label"
  else
    if [ "$sev" = "fail" ]; then
      fail "$label (missing in /proc/cmdline)"
    else
      warn "$label (missing in /proc/cmdline)"
    fi
    need "GRUB: add '$needle' to GRUB_CMDLINE_LINUX_DEFAULT and run: sudo update-grub"
  fi
}

apt_install_tunado3() {
  if ! have apt-get; then
    warn "apt-get not available (cannot install packages)"
    return
  fi

  info "Installing packages (tunado3 baseline)..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    btrfs-progs \
    intel-microcode \
    firmware-misc-nonfree \
    intel-media-va-driver-non-free \
    i965-va-driver-shaders \
    vainfo \
    intel-gpu-tools \
    thermald \
    linux-cpupower \
    powertop \
    msr-tools \
    lm-sensors \
    zram-tools \
    curl wget git vim \
    htop btop \
    pciutils util-linux \
    exfatprogs exfat-fuse \
    ntfs-3g \
    python3 \
    >/dev/null 2>&1 || true

  pass "Package install attempted"
}

ensure_file() {
  local path="$1"
  local content="$2"
  if [ ! -f "$path" ]; then
    printf "%s\n" "$content" > "$path"
    pass "Created $path"
  else
    info "File exists (not overwritten): $path"
  fi
}

ensure_line() {
  local path="$1"
  local line="$2"
  grep -Fxq "$line" "$path" 2>/dev/null || echo "$line" >> "$path"
}

require_root_for_fix

echo ""
echo "Debian Tunado 3.0 audit"
echo "Mode: $MODE"
echo "Fix:  $DO_FIX"
echo ""

if [ "$DO_FIX" -eq 1 ]; then
  apt_install_tunado3
fi

section "1) System"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  pass "OS: ${PRETTY_NAME:-unknown}"
else
  warn "Cannot read /etc/os-release"
fi

if [ -d /sys/firmware/efi ]; then
  pass "UEFI detected"
else
  warn "UEFI not detected"
  need "If you want UEFI, check BIOS boot mode"
fi

if have hostnamectl; then
  HN="$(hostnamectl --static 2>/dev/null || true)"
  [ -n "$HN" ] && pass "Hostname: $HN" || warn "Hostname unknown"
fi

section "2) Key packages (tunado3)"
check_pkg "btrfs-progs" "btrfs-progs installed"
check_pkg "intel-microcode" "intel-microcode installed"
check_pkg "intel-media-va-driver-non-free" "intel media va driver (iHD) installed"
check_pkg "vainfo" "vainfo installed"
check_pkg "thermald" "thermald installed"
check_pkg "zram-tools" "zram-tools installed"
check_pkg "linux-cpupower" "linux-cpupower installed"
check_pkg "msr-tools" "msr-tools installed"
check_pkg "pciutils" "pciutils installed"

section "3) Kernel cmdline (GRUB)"
info "/proc/cmdline:"
cat /proc/cmdline || true

check_cmdline_has "i915 enable guc 3" "i915.enable_guc=3" fail
check_cmdline_has "intel pstate active" "intel_pstate=active" warn
check_cmdline_has "blacklist nouveau and nvidia in cmdline" "modprobe.blacklist=nouveau,nvidia,nvidia_drm,nvidia_modeset" warn
check_cmdline_has "i915 enable fbc 1" "i915.enable_fbc=1" warn
check_cmdline_has "i915 enable psr 0" "i915.enable_psr=0" warn
check_cmdline_has "i915 fastboot 1" "i915.fastboot=1" warn

if grep -q "mitigations=off" /proc/cmdline 2>/dev/null; then
  pass "mitigations off present (security tradeoff)"
else
  warn "mitigations off not set (ok if you prefer security)"
fi

section "4) NVIDIA / nouveau block"
BL="/etc/modprobe.d/blacklist-nvidia.conf"
BL_CONTENT=$'# Tunado3: block nvidia and nouveau\nblacklist nouveau\nblacklist nvidia\nblacklist nvidia_drm\nblacklist nvidia_modeset\noptions nouveau modeset=0\n'

if [ -f "$BL" ]; then
  pass "Blacklist file exists: $BL"
  grep -q "blacklist nouveau" "$BL" && pass "blacklist nouveau present" || warn "blacklist nouveau missing in file"
  grep -q "options nouveau modeset=0" "$BL" && pass "nouveau modeset 0 present" || warn "nouveau modeset 0 missing in file"
else
  warn "Blacklist file missing: $BL"
  need "Create $BL and run: sudo update-initramfs -u"
  if [ "$DO_FIX" -eq 1 ]; then
    printf "%s" "$BL_CONTENT" > "$BL"
    pass "Created blacklist file"
  fi
fi

if have lsmod; then
  if lsmod | grep -q "^nouveau"; then
    fail "nouveau module is loaded (can cause fifo fault spam)"
    need "Apply blacklist + sudo update-initramfs -u + reboot"
  else
    pass "nouveau module not loaded"
  fi
fi

if [ "$DO_FIX" -eq 1 ] && have update-initramfs; then
  info "Updating initramfs..."
  update-initramfs -u >/dev/null 2>&1 || true
  pass "update-initramfs attempted"
fi

section "5) i915 firmware and VA-API"
if [ -d /lib/firmware/i915 ]; then
  DMC="$(ls /lib/firmware/i915/skl_dmc* 2>/dev/null | head -n1 || true)"
  GUC="$(ls /lib/firmware/i915/skl_guc* 2>/dev/null | head -n1 || true)"
  HUC="$(ls /lib/firmware/i915/skl_huc* 2>/dev/null | head -n1 || true)"
  [ -n "$DMC" ] && pass "DMC present: $(basename "$DMC")" || warn "DMC not found (skl_dmc*)"
  [ -n "$GUC" ] && pass "GuC present: $(basename "$GUC")" || warn "GuC not found (skl_guc*)"
  [ -n "$HUC" ] && pass "HuC present: $(basename "$HUC")" || warn "HuC not found (skl_huc*)"
else
  warn "/lib/firmware/i915 not found"
fi

if [ -e /dev/dri/renderD128 ]; then
  pass "/dev/dri/renderD128 exists"
else
  warn "/dev/dri/renderD128 missing"
  need "Check i915 driver and /dev/dri permissions"
fi

if have id; then
  U="${SUDO_USER:-$(id -un)}"
  G="$(id -nG "$U" 2>/dev/null || true)"
  if echo "$G" | grep -qw video && echo "$G" | grep -qw render; then
    pass "User in video and render groups ($U)"
  else
    warn "User not in video/render groups ($U) groups: $G"
    need "Run: sudo usermod -aG video,render $U and relogin"
    if [ "$DO_FIX" -eq 1 ]; then
      usermod -aG video,render "$U" || true
      pass "Added user to video,render (relogin required)"
    fi
  fi
fi

if have vainfo; then
  VA="$(vainfo 2>&1 | head -n 150)"
  if echo "$VA" | grep -q "iHD"; then
    pass "VA-API driver iHD detected"
  else
    warn "VA-API driver iHD not detected (may be i965)"
    need "Install intel-media-va-driver-non-free and set LIBVA_DRIVER_NAME=iHD"
  fi

  if echo "$VA" | grep -q "VAProfileH264.*VAEntrypointEncSlice"; then
    pass "H264 encode entrypoint present (EncSlice)"
  else
    warn "H264 encode entrypoint not found in vainfo"
    need "Recheck enable_guc=3, firmware, and VA-API packages"
  fi
else
  warn "vainfo not found"
fi

section "6) BTRFS subvolumes and mount options"
if have findmnt; then
  FS="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
  if [ "$FS" = "btrfs" ]; then
    pass "Root filesystem is btrfs"
    OPTS="$(findmnt -n -o OPTIONS / 2>/dev/null || true)"
    info "Mount options /: $OPTS"
    echo "$OPTS" | grep -q "compress=zstd" && pass "compress=zstd set on /" || warn "compress=zstd not set on /"
    echo "$OPTS" | grep -q "noatime" && pass "noatime set on /" || warn "noatime not set on /"
    echo "$OPTS" | grep -q "discard=async" && pass "discard=async set on /" || warn "discard=async not set on /"
  else
    warn "Root filesystem is not btrfs (FSTYPE=$FS)"
  fi
else
  warn "findmnt not available"
fi

if have btrfs; then
  SV_LIST="$(btrfs subvolume list / 2>/dev/null | awk '{print $9}' | sort || true)"
  info "Subvolumes:"
  echo "$SV_LIST" | sed 's/^/  - /'

  if [ "$MODE" = "full" ]; then
    for sv in @ @home @docker @postgres @var @snapshots; do
      if echo "$SV_LIST" | grep -qx "$sv"; then
        pass "Subvolume exists: $sv"
      else
        warn "Subvolume missing: $sv"
      fi
    done
    need "If you want full tunado3 layout, create missing subvolumes and mount them in /etc/fstab"
  else
    for sv in @ @home; do
      if echo "$SV_LIST" | grep -qx "$sv"; then
        pass "Subvolume exists: $sv"
      else
        fail "Subvolume missing: $sv"
      fi
    done
  fi
else
  warn "btrfs command not found"
fi

section "7) ZRAM (tunado3 expects zstd, 4096MB, prio 100)"
ZR="/etc/default/zramswap"
if [ -f "$ZR" ]; then
  pass "zramswap config exists: $ZR"
  grep -q '^ALGO=zstd' "$ZR" && pass "ALGO=zstd" || warn "ALGO is not zstd"
  grep -q '^SIZE=4096' "$ZR" && pass "SIZE=4096" || warn "SIZE is not 4096"
  grep -q '^PRIORITY=100' "$ZR" && pass "PRIORITY=100" || warn "PRIORITY is not 100"
else
  warn "zramswap config missing: $ZR"
  need "Create /etc/default/zramswap with ALGO=zstd SIZE=4096 PRIORITY=100"
  if [ "$DO_FIX" -eq 1 ]; then
    cat > "$ZR" <<'EOF'
ALGO=zstd
SIZE=4096
PRIORITY=100
EOF
    pass "Created zramswap config"
  fi
fi

check_service_active "zramswap" "zramswap active"

if [ "$DO_FIX" -eq 1 ] && have systemctl; then
  systemctl restart zramswap >/dev/null 2>&1 || true
  systemctl enable zramswap >/dev/null 2>&1 || true
  pass "zramswap restart/enable attempted"
fi

section "8) Swapfile (tunado3 expects /swap/swapfile 2GB pri=50)"
if have swapon; then
  info "swapon --show:"
  swapon --show || true
else
  warn "swapon not available"
fi

SWDIR="/swap"
SWF="/swap/swapfile"

if [ -f "$SWF" ]; then
  pass "Swapfile exists: $SWF"
else
  warn "Swapfile missing: $SWF"
  need "Create swapfile (btrfs needs NoCoW) and add to /etc/fstab"
  if [ "$DO_FIX" -eq 1 ]; then
    mkdir -p "$SWDIR"

    if have btrfs && btrfs filesystem mkswapfile --help >/dev/null 2>&1; then
      info "Creating swapfile via btrfs filesystem mkswapfile..."
      btrfs filesystem mkswapfile --size 2g "$SWF" >/dev/null 2>&1 || true
    else
      info "Creating swapfile via chattr +C + dd..."
      chattr +C "$SWDIR" >/dev/null 2>&1 || true
      dd if=/dev/zero of="$SWF" bs=1M count=2048 status=none || true
      chmod 600 "$SWF" || true
      mkswap "$SWF" >/dev/null 2>&1 || true
    fi

    swapon -p 50 "$SWF" >/dev/null 2>&1 || true
    ensure_line /etc/fstab "$SWF none swap sw,pri=50 0 0"
    pass "Swapfile created/enabled (pri=50) attempt done"
  fi
fi

section "9) sysctl (tunado3 baseline)"
SYS="/etc/sysctl.d/99-performance.conf"
if [ -f "$SYS" ]; then
  pass "sysctl file exists: $SYS"
else
  warn "sysctl file missing: $SYS"
  need "Create $SYS and apply with: sudo sysctl -p $SYS"
  if [ "$DO_FIX" -eq 1 ]; then
    cat > "$SYS" <<'EOF'
kernel.sched_migration_cost_ns=5000000
kernel.sched_min_granularity_ns=2000000
kernel.sched_wakeup_granularity_ns=3000000
kernel.sched_latency_ns=12000000
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
    sysctl -p "$SYS" >/dev/null 2>&1 || true
    pass "sysctl file created and applied"
  fi
fi

if [ -f "$SYS" ]; then
  for kv in \
    "vm.swappiness=150" \
    "vm.overcommit_memory=2" \
    "vm.overcommit_ratio=80" \
    "fs.inotify.max_user_watches=1048576" \
    "net.core.default_qdisc=fq_codel" \
    "net.ipv4.tcp_congestion_control=bbr"
  do
    grep -q "^$kv" "$SYS" && pass "sysctl has $kv" || warn "sysctl missing $kv"
  done
fi

section "10) services: thermald, fstrim, cpupower"
check_service_active "thermald" "thermald active"
check_service_enabled "fstrim.timer" "fstrim.timer enabled"
check_service_active "fstrim.timer" "fstrim.timer active"

if have cpupower; then
  GOV="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true)"
  [ -n "$GOV" ] && pass "CPU governor: $GOV" || warn "Cannot read CPU governor"
else
  warn "cpupower not installed"
fi

if [ "$DO_FIX" -eq 1 ] && have systemctl; then
  systemctl enable --now thermald >/dev/null 2>&1 || true
  systemctl enable --now fstrim.timer >/dev/null 2>&1 || true
  pass "thermald/fstrim enable attempted"
fi

section "11) docker (tunado3 overlay2 and valid daemon.json)"
if have docker; then
  pass "docker installed"
  check_service_active "docker" "docker active"
  DRV="$(docker info 2>/dev/null | awk -F: '/Storage Driver/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' || true)"
  [ -n "$DRV" ] && info "Docker storage driver: $DRV"
  [ "$DRV" = "overlay2" ] && pass "Docker uses overlay2" || warn "Docker does not use overlay2"
else
  warn "docker not installed (ok if not needed now)"
fi

DJ="/etc/docker/daemon.json"
if [ -f "$DJ" ] && have python3; then
  if python3 -m json.tool "$DJ" >/dev/null 2>&1; then
    pass "daemon.json is valid JSON"
  else
    fail "daemon.json invalid JSON (remove // comments, fix commas)"
    need "Fix /etc/docker/daemon.json and restart docker"
  fi
elif [ -f "$DJ" ]; then
  warn "daemon.json exists, but python3 missing for validation"
fi

section "12) tdp unlock (audit only)"
TDP="/usr/local/bin/tdp-unlock.sh"
TDPSVC="/etc/systemd/system/tdp-unlock.service"
[ -f "$TDP" ] && pass "TDP script exists: $TDP" || warn "TDP script missing (optional)"
[ -f "$TDPSVC" ] && pass "TDP service exists: $TDPSVC" || warn "TDP service missing (optional)"

section "Summary"
echo "Pass: $PASS"
echo "Warn: $WARN"
echo "Fail: $FAIL"

if [ "${#SUG[@]}" -gt 0 ]; then
  echo ""
  echo "Suggested next actions:"
  printf "%s\n" "${SUG[@]}" | awk '!seen[$0]++' | nl -w2 -s'. '
fi

echo ""
if [ "$DO_FIX" -eq 1 ]; then
  echo "Safe fix attempted. Recommended: reboot."
fi
