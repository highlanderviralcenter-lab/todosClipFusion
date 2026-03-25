
#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${BLUE}▶${NC} $1"
}

ok() {
  echo -e "${GREEN}✅${NC} $1"
}

warn() {
  echo -e "${YELLOW}⚠️${NC} $1"
}

die() {
  echo -e "${RED}❌${NC} $1" >&2
  exit 1
}

require_root() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "Execute como root."
}

ensure_line() {
  local line="$1"
  local file="$2"
  touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

replace_marked_block() {
  local file="$1"
  local start="$2"
  local end="$3"
  local tmp
  tmp="$(mktemp)"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  awk -v s="$start" -v e="$end" '
    $0==s {skip=1; next}
    $0==e {skip=0; next}
    !skip {print}
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
  cat >> "$file" <<EOF_BLOCK
$start
$4
$end
EOF_BLOCK
}

install_checker() {
  cat > /usr/local/bin/clipfusion-check.sh <<'EOF_CHECKER'
#!/usr/bin/env bash
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local desc="$1"
    local cmd="$2"
    local severity="${3:-FAIL}"

    if eval "$cmd" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}✅${NC} $desc"
        return 0
    else
        if [ "$severity" = "WARN" ]; then
            WARN=$((WARN + 1))
            echo -e "  ${YELLOW}⚠️${NC} $desc"
        else
            FAIL=$((FAIL + 1))
            echo -e "  ${RED}❌${NC} $desc"
        fi
        return 1
    fi
}

section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
}

check_mount_opts() {
    local mountpoint="$1"
    local label="$2"
    shift 2
    local opts
    opts="$(findmnt -n -o OPTIONS "$mountpoint" 2>/dev/null || true)"
    if [ -z "$opts" ]; then
        echo -e "  ${RED}❌${NC} $label montado"
        FAIL=$((FAIL + 1))
        return 1
    fi

    echo -e "  ${GREEN}✅${NC} $label montado"
    PASS=$((PASS + 1))

    local opt
    for opt in "$@"; do
        if echo "$opts" | tr ',' '\n' | grep -Fxq "$opt"; then
            echo -e "  ${GREEN}✅${NC} $label: $opt"
            PASS=$((PASS + 1))
        else
            echo -e "  ${RED}❌${NC} $label: $opt"
            FAIL=$((FAIL + 1))
        fi
    done
}

check_i3_line() {
    local desc="$1"
    local pattern="$2"
    if grep -Eq "$pattern" /home/highlander/.config/i3/config 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}❌${NC} $desc"
        FAIL=$((FAIL + 1))
    fi
}

check_bashrc_line() {
    local desc="$1"
    local pattern="$2"
    if grep -Eq "$pattern" /home/highlander/.bashrc 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}❌${NC} $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║      CLIPFUSION CHECK - DEBIAN TUNADO 3.0 (SEM DOCKER/PG)        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"

section "1. HARDWARE E SISTEMA BASE"
echo "  CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null)"
echo "  Kernel: $(uname -r)"
echo "  RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo "  Hostname: $(hostname)"
echo "  Timezone: $(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo desconhecida)"
check "CPU Intel i5-6200U" "lscpu | grep -q '6200U'"
check "RAM >= 7.5GB" "[ \$(free -m | awk '/^Mem:/{print \$2}') -ge 7500 ]"
check "Debian 12 / bookworm" "grep -q 'bookworm' /etc/os-release"
check "UEFI ativo" "[ -d /sys/firmware/efi ]"
check "Timezone America/Sao_Paulo" "timedatectl show -p Timezone --value 2>/dev/null | grep -qx 'America/Sao_Paulo' || grep -qx 'America/Sao_Paulo' /etc/timezone 2>/dev/null" "WARN"
check "Usuário highlander existe" "id highlander >/dev/null 2>&1"
check "Hostname clipfusion ou highlander" "hostname | grep -qiE 'clipfusion|highlander'" "WARN"

section "2. BTRFS E MOUNTS ESSENCIAIS"
check "Raiz em BTRFS" "findmnt -n -o FSTYPE / | grep -qx 'btrfs'"
check "Subvolume @ existe" "btrfs subvolume list / 2>/dev/null | awk '{print \$NF}' | grep -qx '@'"
check "Subvolume @home existe" "btrfs subvolume list / 2>/dev/null | awk '{print \$NF}' | grep -qx '@home'"
check "Subvolume @var existe" "btrfs subvolume list / 2>/dev/null | awk '{print \$NF}' | grep -qx '@var'"
check "Subvolume @snapshots existe" "btrfs subvolume list / 2>/dev/null | awk '{print \$NF}' | grep -qx '@snapshots'"
check "BTRFS sem erros" "btrfs device stats / 2>/dev/null | awk '{sum+=\$NF} END {exit(sum>0)}'"
check_mount_opts "/" "/" "compress=zstd:3" "noatime" "ssd" "discard=async" "space_cache=v2"
check_mount_opts "/home" "/home" "compress=zstd:3" "noatime" "ssd" "discard=async"
check_mount_opts "/var" "/var" "compress=zstd:3" "noatime" "ssd" "discard=async"
check_mount_opts "/.snapshots" "/.snapshots" "compress=zstd:3" "noatime" "ssd" "discard=async"
check "fstab: / em subvol=@" "grep -Eq '^[^#]+[[:space:]]+/[[:space:]]+btrfs[[:space:]].*subvol=@([,[:space:]]|$)' /etc/fstab"
check "fstab: /home em subvol=@home" "grep -Eq '^[^#]+[[:space:]]+/home[[:space:]]+btrfs[[:space:]].*subvol=@home([,[:space:]]|$)' /etc/fstab"
check "fstab: /var em subvol=@var" "grep -Eq '^[^#]+[[:space:]]+/var[[:space:]]+btrfs[[:space:]].*subvol=@var([,[:space:]]|$)' /etc/fstab"
check "fstab: /.snapshots em subvol=@snapshots" "grep -Eq '^[^#]+[[:space:]]+/\.snapshots[[:space:]]+btrfs[[:space:]].*subvol=@snapshots([,[:space:]]|$)' /etc/fstab"

section "3. KERNEL TUNING + NVIDIA BLOQUEADA"
check "blacklist-nvidia.conf existe" "[ -f /etc/modprobe.d/blacklist-nvidia.conf ]"
check "blacklist nouveau" "grep -q '^blacklist nouveau' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "blacklist nvidia" "grep -q '^blacklist nvidia$' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "blacklist nvidia_drm" "grep -q '^blacklist nvidia_drm' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "blacklist nvidia_modeset" "grep -q '^blacklist nvidia_modeset' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "nouveau modeset=0" "grep -q '^options nouveau modeset=0' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "Módulo nouveau não carregado" "! lsmod | grep -q '^nouveau'"
check "Módulo nvidia não carregado" "! lsmod | grep -q '^nvidia'"
check "i915.enable_guc=3" "grep -qw 'i915.enable_guc=3' /proc/cmdline"
check "intel_pstate=active" "grep -qw 'intel_pstate=active' /proc/cmdline"
check "intel_pstate.max_perf_pct=100" "grep -qw 'intel_pstate.max_perf_pct=100' /proc/cmdline"
check "i915.enable_fbc=1" "grep -qw 'i915.enable_fbc=1' /proc/cmdline"
check "i915.enable_psr=0" "grep -qw 'i915.enable_psr=0' /proc/cmdline"
check "i915.fastboot=1" "grep -qw 'i915.fastboot=1' /proc/cmdline"
check "i915.modeset=1" "grep -qw 'i915.modeset=1' /proc/cmdline"
check "modprobe.blacklist=nouveau,nvidia,nvidia_drm,nvidia_modeset" "grep -qw 'modprobe.blacklist=nouveau,nvidia,nvidia_drm,nvidia_modeset' /proc/cmdline"
check "processor.max_cstate=5" "grep -qw 'processor.max_cstate=5' /proc/cmdline"
check "intel_iommu=on" "grep -qw 'intel_iommu=on' /proc/cmdline"
check "iommu=pt" "grep -qw 'iommu=pt' /proc/cmdline"
check "nmi_watchdog=0" "grep -qw 'nmi_watchdog=0' /proc/cmdline"
check "nowatchdog" "grep -qw 'nowatchdog' /proc/cmdline"
check "tsc=reliable" "grep -qw 'tsc=reliable' /proc/cmdline"
check "clocksource=tsc" "grep -qw 'clocksource=tsc' /proc/cmdline"
check "hpet=disable" "grep -qw 'hpet=disable' /proc/cmdline"
check "audit=0" "grep -qw 'audit=0' /proc/cmdline"
check "mitigations=off" "grep -qw 'mitigations=off' /proc/cmdline" "WARN"

section "4. VA-API / INTEL HD 520"
check "Firmware DMC (skl_dmc)" "ls /lib/firmware/i915/skl_dmc_*.bin 2>/dev/null | grep -q ."
check "Firmware GuC (skl_guc)" "ls /lib/firmware/i915/skl_guc_*.bin 2>/dev/null | grep -q ."
check "Firmware HuC (skl_huc)" "ls /lib/firmware/i915/skl_huc_*.bin 2>/dev/null | grep -q ."
check "Render node /dev/dri/renderD128" "[ -e /dev/dri/renderD128 ]"
check "Pacote intel-media-va-driver-non-free" "dpkg -l 2>/dev/null | grep -q '^ii.*intel-media-va-driver-non-free'"
check "Pacote i965-va-driver-shaders" "dpkg -l 2>/dev/null | grep -q '^ii.*i965-va-driver-shaders'"
check "Pacote vainfo" "command -v vainfo >/dev/null 2>&1"
check "Pacote intel-gpu-tools" "dpkg -l 2>/dev/null | grep -q '^ii.*intel-gpu-tools'"
check "Driver iHD ativo" "vainfo 2>&1 | grep -q 'Driver version: Intel iHD'"
check "H.264 VA-API encode disponível" "vainfo 2>&1 | grep -q 'VAProfileH264Main.*VAEntrypointEncSlice'"
check "LIBVA_DRIVER_NAME=iHD" "grep -q 'LIBVA_DRIVER_NAME=iHD' /etc/environment 2>/dev/null || grep -q 'LIBVA_DRIVER_NAME=iHD' /home/highlander/.bashrc 2>/dev/null"
check "LIBVA_DRIVERS_PATH configurado" "grep -q 'LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri' /etc/environment 2>/dev/null || grep -q 'LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri' /home/highlander/.bashrc 2>/dev/null"

if command -v ffmpeg >/dev/null 2>&1 && [ -e /dev/dri/renderD128 ]; then
    TMP_OUT="/tmp/clipfusion-vaapi-check.mp4"
    LOG_OUT="/tmp/clipfusion-vaapi-check.log"
    if ffmpeg -hide_banner -y -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
        -f lavfi -i testsrc=duration=2:size=1280x720:rate=30 \
        -vf 'format=nv12,hwupload' \
        -c:v h264_vaapi -b:v 3M \
        "$TMP_OUT" >"$LOG_OUT" 2>&1; then
        echo -e "  ${GREEN}✅${NC} Smoke test ffmpeg VA-API"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}❌${NC} Smoke test ffmpeg VA-API"
        FAIL=$((FAIL + 1))
    fi
    rm -f "$TMP_OUT" "$LOG_OUT"
else
    echo -e "  ${YELLOW}⚠️${NC} Smoke test ffmpeg VA-API (ffmpeg ausente)"
    WARN=$((WARN + 1))
fi

section "5. ZRAM"
check "Arquivo /etc/default/zramswap" "[ -f /etc/default/zramswap ]"
check "ALGO=zstd" "grep -q '^ALGO=zstd' /etc/default/zramswap 2>/dev/null"
check "SIZE=4096" "grep -q '^SIZE=4096' /etc/default/zramswap 2>/dev/null"
check "PRIORITY=100" "grep -q '^PRIORITY=100' /etc/default/zramswap 2>/dev/null"
check "zramswap habilitado" "systemctl is-enabled zramswap >/dev/null 2>&1"
check "zramswap ativo" "systemctl is-active zramswap >/dev/null 2>&1"
check "zram0 em uso" "swapon --show 2>/dev/null | grep -q 'zram0'"
check "Prioridade do zram = 100" "swapon --show=NAME,PRIO 2>/dev/null | awk '\$1 ~ /zram0/ {print \$2}' | grep -qx '100'"

section "6. SWAPFILE SSD"
check "Diretório /swap existe" "[ -d /swap ]"
check "Diretório /swap com +C" "lsattr -d /swap 2>/dev/null | awk '{print \$1}' | grep -q 'C'"
check "Arquivo /swap/swapfile existe" "[ -f /swap/swapfile ]"
check "Swapfile >= 2GB" "[ \$(stat -c%s /swap/swapfile 2>/dev/null || echo 0) -ge 2000000000 ]"
check "Permissão do swapfile = 600" "[ \"\$(stat -c '%a' /swap/swapfile 2>/dev/null)\" = '600' ]"
check "Swapfile ativo" "swapon --show 2>/dev/null | grep -q '/swap/swapfile'"
check "Swapfile prioridade 50" "swapon --show=NAME,PRIO 2>/dev/null | awk '\$1 == \"/swap/swapfile\" {print \$2}' | grep -qx '50'"
check "fstab contém swapfile pri=50" "grep -Eq '^[^#]*/swap/swapfile[[:space:]]+none[[:space:]]+swap[[:space:]].*pri=50' /etc/fstab"

section "7. SYSCTL"
check "Arquivo /etc/sysctl.d/99-performance.conf" "[ -f /etc/sysctl.d/99-performance.conf ]"
check "kernel.sched_migration_cost_ns=5000000" "[ \"\$(sysctl -n kernel.sched_migration_cost_ns 2>/dev/null)\" = '5000000' ]"
check "kernel.sched_autogroup_enabled=1" "[ \"\$(sysctl -n kernel.sched_autogroup_enabled 2>/dev/null)\" = '1' ]"
check "vm.swappiness=150" "[ \"\$(sysctl -n vm.swappiness 2>/dev/null)\" = '150' ]"
check "vm.vfs_cache_pressure=50" "[ \"\$(sysctl -n vm.vfs_cache_pressure 2>/dev/null)\" = '50' ]"
check "vm.dirty_ratio=30" "[ \"\$(sysctl -n vm.dirty_ratio 2>/dev/null)\" = '30' ]"
check "vm.dirty_background_ratio=10" "[ \"\$(sysctl -n vm.dirty_background_ratio 2>/dev/null)\" = '10' ]"
check "vm.dirty_expire_centisecs=1000" "[ \"\$(sysctl -n vm.dirty_expire_centisecs 2>/dev/null)\" = '1000' ]"
check "vm.dirty_writeback_centisecs=500" "[ \"\$(sysctl -n vm.dirty_writeback_centisecs 2>/dev/null)\" = '500' ]"
check "vm.min_free_kbytes=131072" "[ \"\$(sysctl -n vm.min_free_kbytes 2>/dev/null)\" = '131072' ]"
check "vm.overcommit_memory=2" "[ \"\$(sysctl -n vm.overcommit_memory 2>/dev/null)\" = '2' ]"
check "vm.overcommit_ratio=80" "[ \"\$(sysctl -n vm.overcommit_ratio 2>/dev/null)\" = '80' ]"
check "net.core.default_qdisc=fq_codel" "[ \"\$(sysctl -n net.core.default_qdisc 2>/dev/null)\" = 'fq_codel' ]"
check "net.ipv4.tcp_congestion_control=bbr" "[ \"\$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)\" = 'bbr' ]"
check "net.core.netdev_max_backlog=16384" "[ \"\$(sysctl -n net.core.netdev_max_backlog 2>/dev/null)\" = '16384' ]"
check "net.core.somaxconn=8192" "[ \"\$(sysctl -n net.core.somaxconn 2>/dev/null)\" = '8192' ]"
check "net.ipv4.tcp_max_syn_backlog=8192" "[ \"\$(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null)\" = '8192' ]"
check "net.ipv4.tcp_fastopen=3" "[ \"\$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null)\" = '3' ]"
check "net.ipv4.tcp_slow_start_after_idle=0" "[ \"\$(sysctl -n net.ipv4.tcp_slow_start_after_idle 2>/dev/null)\" = '0' ]"
check "fs.inotify.max_user_watches=1048576" "[ \"\$(sysctl -n fs.inotify.max_user_watches 2>/dev/null)\" = '1048576' ]"
check "fs.file-max=2097152" "[ \"\$(sysctl -n fs.file-max 2>/dev/null)\" = '2097152' ]"
check "fs.aio-max-nr=524288" "[ \"\$(sysctl -n fs.aio-max-nr 2>/dev/null)\" = '524288' ]"

section "8. TDP UNLOCK / CPU / THERMAL"
check "Pacote msr-tools" "dpkg -l 2>/dev/null | grep -q '^ii.*msr-tools'"
check "Módulo msr carregado" "lsmod | grep -q '^msr'"
check "msr em /etc/modules" "grep -qx 'msr' /etc/modules 2>/dev/null"
check "Script /usr/local/bin/tdp-unlock.sh" "[ -f /usr/local/bin/tdp-unlock.sh ]"
check "PL1/PL2 corretos no script" "grep -q '0x00dc8004dc8000' /usr/local/bin/tdp-unlock.sh 2>/dev/null"
check "Turbo 2.7GHz no script" "grep -q '0x1B1B1B1B1B1B1B1B' /usr/local/bin/tdp-unlock.sh 2>/dev/null"
check "tdp-unlock.service existe" "[ -f /etc/systemd/system/tdp-unlock.service ]"
check "tdp-unlock habilitado" "systemctl is-enabled tdp-unlock.service >/dev/null 2>&1"
check "tdp-unlock ativo" "systemctl is-active tdp-unlock.service >/dev/null 2>&1 || systemctl is-active tdp-unlock >/dev/null 2>&1"
check "Pacote thermald" "dpkg -l 2>/dev/null | grep -q '^ii.*thermald'"
check "thermald ativo" "systemctl is-active thermald >/dev/null 2>&1"
check "thermald habilitado" "systemctl is-enabled thermald >/dev/null 2>&1"
check "Pacote linux-cpupower" "dpkg -l 2>/dev/null | grep -q '^ii.*linux-cpupower'"
check "Governor performance" "cpupower frequency-info 2>/dev/null | grep -q 'governor \"performance\"' || grep -q 'GOVERNOR=\"performance\"' /etc/default/cpupower 2>/dev/null"
check "fstrim.timer habilitado" "systemctl is-enabled fstrim.timer >/dev/null 2>&1"
check "fstrim.timer ativo" "systemctl is-active fstrim.timer >/dev/null 2>&1"

if command -v sensors >/dev/null 2>&1; then
    temp="$(sensors 2>/dev/null | awk '/Core 0:/{gsub(/[+°C]/,"",$3); split($3,a,"."); print a[1]; exit}')"
    if [ -n "${temp:-}" ]; then
        echo -e "  ${GREEN}✅${NC} Temperatura lida: ${temp}°C"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}⚠️${NC} Temperatura não encontrada no sensors"
        WARN=$((WARN + 1))
    fi
else
    echo -e "  ${YELLOW}⚠️${NC} lm-sensors / sensors ausente"
    WARN=$((WARN + 1))
fi

section "9. PACOTES ESSENCIAIS"
check "firmware-misc-nonfree" "dpkg -l 2>/dev/null | grep -q '^ii.*firmware-misc-nonfree'"
check "intel-microcode" "dpkg -l 2>/dev/null | grep -q '^ii.*intel-microcode'"
check "btrfs-progs" "dpkg -l 2>/dev/null | grep -q '^ii.*btrfs-progs'"
check "zram-tools" "dpkg -l 2>/dev/null | grep -q '^ii.*zram-tools'"
check "lm-sensors" "dpkg -l 2>/dev/null | grep -q '^ii.*lm-sensors'"
check "powertop" "dpkg -l 2>/dev/null | grep -q '^ii.*powertop'" "WARN"
check "htop" "command -v htop >/dev/null 2>&1" "WARN"
check "btop" "command -v btop >/dev/null 2>&1" "WARN"
check "curl" "command -v curl >/dev/null 2>&1"
check "wget" "command -v wget >/dev/null 2>&1"
check "git" "command -v git >/dev/null 2>&1"
check "vim" "command -v vim >/dev/null 2>&1"
check "neofetch" "command -v neofetch >/dev/null 2>&1" "WARN"

section "10. i3wm / LIGHTDM / CONFIG DO CLIPFUSION"
check "Pacote xorg" "dpkg -l 2>/dev/null | grep -q '^ii.*xorg'"
check "Pacote i3-wm" "dpkg -l 2>/dev/null | grep -q '^ii.*i3-wm'"
check "Pacote i3status" "dpkg -l 2>/dev/null | grep -q '^ii.*i3status'"
check "Pacote i3lock" "dpkg -l 2>/dev/null | grep -q '^ii.*i3lock'"
check "Pacote lightdm" "dpkg -l 2>/dev/null | grep -q '^ii.*lightdm '"
check "Pacote lightdm-gtk-greeter" "dpkg -l 2>/dev/null | grep -q '^ii.*lightdm-gtk-greeter'"
check "Pacote rxvt-unicode" "dpkg -l 2>/dev/null | grep -q '^ii.*rxvt-unicode'"
check "Pacote rofi" "dpkg -l 2>/dev/null | grep -q '^ii.*rofi'"
check "Pacote feh" "dpkg -l 2>/dev/null | grep -q '^ii.*feh'"
check "Pacote firefox-esr" "dpkg -l 2>/dev/null | grep -q '^ii.*firefox-esr'"
check "Pacote thunar" "dpkg -l 2>/dev/null | grep -q '^ii.*thunar'"
check "Pacote fonts-firacode" "dpkg -l 2>/dev/null | grep -q '^ii.*fonts-firacode'"
check "Pacote fonts-noto" "dpkg -l 2>/dev/null | grep -q '^ii.*fonts-noto'"
check "Pacote fonts-noto-color-emoji" "dpkg -l 2>/dev/null | grep -q '^ii.*fonts-noto-color-emoji'"
check "lightdm habilitado" "systemctl is-enabled lightdm >/dev/null 2>&1"
check "Arquivo /home/highlander/.config/i3/config existe" "[ -f /home/highlander/.config/i3/config ]"
check "Pasta /home/highlander/.config/i3 existe" "[ -d /home/highlander/.config/i3 ]"
check "Dono da pasta i3 é highlander" "[ \"\$(stat -c '%U:%G' /home/highlander/.config/i3 2>/dev/null)\" = 'highlander:highlander' ]"
check_i3_line "i3: gaps inner 0" '^[[:space:]]*gaps inner 0([[:space:]]|$)'
check_i3_line "i3: gaps outer 0" '^[[:space:]]*gaps outer 0([[:space:]]|$)'
check_i3_line "i3: default_border pixel 1" '^[[:space:]]*default_border pixel 1([[:space:]]|$)'
check_i3_line "i3: atalho btop" 'bindsym[[:space:]]+\$mod\+Shift\+m[[:space:]]+exec[[:space:]]+urxvt[[:space:]]+-e[[:space:]]+btop'
check_i3_line "i3: atalho intel_gpu_top" 'bindsym[[:space:]]+\$mod\+Shift\+g[[:space:]]+exec[[:space:]]+urxvt[[:space:]]+-e[[:space:]]+intel_gpu_top'
check_i3_line "i3: atalho firefox" 'bindsym[[:space:]]+\$mod\+b[[:space:]]+exec[[:space:]]+firefox-esr'
check_i3_line "i3: workspace ClipFusion 4:render" 'assign[[:space:]]+\[class="?clipfusion"?\][[:space:]]+.*workspace[[:space:]]+4:render'

section "11. USUÁRIO / EFI"
check "highlander no grupo video" "id highlander 2>/dev/null | grep -q '(video)'"
check "highlander no grupo render" "id highlander 2>/dev/null | grep -q '(render)'"
check "EFI montado em /boot/efi" "findmnt -n /boot/efi >/dev/null 2>&1"
check "grubx64.efi existe" "[ -f /boot/efi/EFI/debian/grubx64.efi ]"
check "grub.cfg existe" "[ -f /boot/grub/grub.cfg ]"

section "12. SCRIPTS / SNAPSHOT / ALIASES"
check "validate-system.sh existe" "[ -x /usr/local/bin/validate-system.sh ]" "WARN"
check "monitor-system.sh existe" "[ -x /usr/local/bin/monitor-system.sh ]"
check "snapshot-weekly.sh existe" "[ -x /usr/local/bin/snapshot-weekly.sh ]"
check "snapshot-weekly cria snapshot root" "grep -q 'btrfs subvolume snapshot -r /' /usr/local/bin/snapshot-weekly.sh 2>/dev/null"
check "snapshot-weekly cria snapshot home" "grep -q 'btrfs subvolume snapshot -r /home' /usr/local/bin/snapshot-weekly.sh 2>/dev/null"
check "snapshot-weekly KEEP=7" "grep -q '^KEEP=7' /usr/local/bin/snapshot-weekly.sh 2>/dev/null"
check "snapshot-weekly faz vacuum do journal" "grep -q 'journalctl --vacuum-time=7d' /usr/local/bin/snapshot-weekly.sh 2>/dev/null"
check "Crontab semanal do snapshot" "crontab -l 2>/dev/null | grep -Fqx '0 3 * * 0 /usr/local/bin/snapshot-weekly.sh'"
check_bashrc_line "alias ll" "alias ll='ls -lah'"
check_bashrc_line "alias update" "alias update='sudo apt update && sudo apt upgrade -y'"
check_bashrc_line "alias temps" "alias temps='sensors \| grep Core'"
check_bashrc_line "alias validate" "alias validate='sudo /usr/local/bin/validate-system\.sh'"
check_bashrc_line "alias monitor" "alias monitor='sudo /usr/local/bin/monitor-system\.sh'"
check_bashrc_line "alias snapshot" "alias snapshot='sudo /usr/local/bin/snapshot-weekly\.sh'"
check_bashrc_line "export LIBVA_DRIVER_NAME=iHD no bashrc" 'export LIBVA_DRIVER_NAME=iHD'
check_bashrc_line "export LIBVA_DRIVERS_PATH no bashrc" 'export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri'

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "PASS: $PASS | WARN: $WARN | FAIL: $FAIL"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ SISTEMA OK PARA COMEÇAR O CLIPFUSION${NC}"
    exit 0
else
    echo -e "${RED}❌ AJUSTES NECESSÁRIOS ANTES DE COMEÇAR O CLIPFUSION${NC}"
    exit 1
fi

EOF_CHECKER
  chmod 755 /usr/local/bin/clipfusion-check.sh

  cat > /usr/local/bin/validate-system.sh <<'EOF_VALIDATE'
#!/usr/bin/env bash
exec /usr/local/bin/clipfusion-check.sh "$@"
EOF_VALIDATE
  chmod 755 /usr/local/bin/validate-system.sh
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  log "Instalando pacotes pendentes"
  apt-get update
  apt-get install -y \
    intel-media-va-driver-non-free \
    i965-va-driver-shaders \
    ffmpeg \
    xorg i3-wm i3status i3lock \
    lightdm lightdm-gtk-greeter \
    rxvt-unicode rofi feh firefox-esr thunar \
    fonts-firacode fonts-noto fonts-noto-color-emoji \
    thermald linux-cpupower msr-tools \
    lm-sensors intel-gpu-tools vainfo
  ok "Pacotes instalados"
}

fix_user_groups() {
  log "Ajustando usuário e grupos"
  id highlander >/dev/null 2>&1 || die "Usuário highlander não existe."
  getent group render >/dev/null || groupadd render
  usermod -aG video,render highlander
  ok "Usuário highlander ajustado nos grupos video/render"
}

fix_msr_and_tdp() {
  log "Ajustando MSR, TDP e governor"
  ensure_line "msr" /etc/modules
  modprobe msr || true

  cat > /usr/local/bin/tdp-unlock.sh <<'EOF_TDP'
#!/usr/bin/env bash
set -e
modprobe msr || true
wrmsr -a 0x610 0x00dc8004dc8000
wrmsr -a 0x1ad 0x1B1B1B1B1B1B1B1B
wrmsr -a 0x618 0x0
echo "TDP unlocked: PL1/PL2 ajustados e turbo 2.7GHz"
EOF_TDP
  chmod 755 /usr/local/bin/tdp-unlock.sh

  cat > /etc/systemd/system/tdp-unlock.service <<'EOF_TDPSVC'
[Unit]
Description=TDP Unlock i5-6200U
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tdp-unlock.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_TDPSVC

  cat > /etc/default/cpupower <<'EOF_CPUPOWER'
GOVERNOR="performance"
EOF_CPUPOWER

  systemctl daemon-reload
  systemctl enable --now thermald >/dev/null 2>&1 || true
  systemctl enable --now cpupower >/dev/null 2>&1 || true
  systemctl enable --now tdp-unlock.service >/dev/null 2>&1 || true
  systemctl enable --now fstrim.timer >/dev/null 2>&1 || true
  ok "MSR/TDP/cpupower ajustados"
}

fix_vaapi_env() {
  log "Ajustando ambiente VA-API"
  ensure_line "LIBVA_DRIVER_NAME=iHD" /etc/environment
  ensure_line "LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri" /etc/environment
  ok "Variáveis LIBVA configuradas"
}

fix_sysctl() {
  log "Aplicando sysctl completo"
  cat > /etc/sysctl.d/99-performance.conf <<'EOF_SYSCTL'
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
EOF_SYSCTL

  sysctl -p /etc/sysctl.d/99-performance.conf >/dev/null || true
  ok "sysctl aplicado"
}

fix_i3() {
  log "Ajustando i3wm / LightDM / sessão"
  mkdir -p /home/highlander/.config/i3
  if [ ! -f /home/highlander/.config/i3/config ] && [ -f /etc/i3/config ]; then
    cp /etc/i3/config /home/highlander/.config/i3/config
  elif [ ! -f /home/highlander/.config/i3/config ]; then
    touch /home/highlander/.config/i3/config
  fi

  replace_marked_block /home/highlander/.config/i3/config \
    "# >>> CLIPFUSION BLOCK >>>" \
    "# <<< CLIPFUSION BLOCK <<<" \
'gaps inner 0
gaps outer 0
default_border pixel 1

bindsym $mod+Shift+m exec urxvt -e btop
bindsym $mod+Shift+g exec urxvt -e intel_gpu_top
bindsym $mod+b exec firefox-esr

assign [class="clipfusion"] workspace 4:render'

  chown -R highlander:highlander /home/highlander/.config

  mkdir -p /etc/X11
  echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
  systemctl enable lightdm >/dev/null 2>&1 || true
  systemctl restart lightdm >/dev/null 2>&1 || true
  ok "i3wm e LightDM ajustados"
}

fix_scripts_and_aliases() {
  log "Criando scripts auxiliares e aliases"
  cat > /usr/local/bin/monitor-system.sh <<'EOF_MONITOR'
#!/usr/bin/env bash
watch -n 2 '
echo "CPU:"
grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2
echo
echo "TEMP:"
sensors 2>/dev/null | grep -E "Core 0|Package id 0" || true
echo
echo "MEM:"
free -h
echo
echo "SWAP:"
swapon --show
echo
echo "GPU:"
command -v intel_gpu_top >/dev/null && echo "intel_gpu_top disponível" || echo "intel_gpu_top ausente"
'
EOF_MONITOR
  chmod 755 /usr/local/bin/monitor-system.sh

  cat > /usr/local/bin/snapshot-weekly.sh <<'EOF_SNAPSHOT'
#!/usr/bin/env bash
set -e
DATE=$(date +%Y%m%d-%H%M)
KEEP=7
btrfs subvolume snapshot -r / /.snapshots/root-$DATE
btrfs subvolume snapshot -r /home /.snapshots/home-$DATE
echo "$(date): Snapshot $DATE criado" >> /var/log/snapshots.log
ls -1dt /.snapshots/root-* 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r btrfs subvolume delete
ls -1dt /.snapshots/home-* 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r btrfs subvolume delete
journalctl --vacuum-time=7d
EOF_SNAPSHOT
  chmod 755 /usr/local/bin/snapshot-weekly.sh

  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"
  printf "%s
" "$current_cron" | grep -Fqx '0 3 * * 0 /usr/local/bin/snapshot-weekly.sh' || {
    ( printf "%s
" "$current_cron"; echo '0 3 * * 0 /usr/local/bin/snapshot-weekly.sh' ) | crontab -
  }

  replace_marked_block /home/highlander/.bashrc \
    "# >>> CLIPFUSION ALIASES >>>" \
    "# <<< CLIPFUSION ALIASES <<<" \
"alias ll='ls -lah'
alias update='sudo apt update && sudo apt upgrade -y'
alias temps='sensors | grep Core'
alias validate='sudo /usr/local/bin/validate-system.sh'
alias monitor='sudo /usr/local/bin/monitor-system.sh'
alias snapshot='sudo /usr/local/bin/snapshot-weekly.sh'
export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri"

  chown highlander:highlander /home/highlander/.bashrc
  ok "Scripts e aliases criados"
}

main() {
  require_root
  install_packages
  fix_user_groups
  fix_msr_and_tdp
  fix_vaapi_env
  fix_sysctl
  fix_i3
  install_checker
  fix_scripts_and_aliases

  echo
  log "Rodando validação final"
  /usr/local/bin/clipfusion-check.sh || true

  echo
  warn "Se o único erro restante for RAM >= 7.5GB, isso depende do hardware e não do script."
}

main "$@"
