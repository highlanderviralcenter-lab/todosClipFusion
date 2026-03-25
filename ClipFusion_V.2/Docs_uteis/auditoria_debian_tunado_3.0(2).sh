#!/bin/bash
# ==============================================================================
# AUDITORIA DEBIAN TUNADO 3.0 - NIVEL FLORENCE
# Verifica cada detalhe do documento oficial
# Gera relatorio em Markdown
# ==============================================================================

set -e

RELATORIO="/root/auditoria_debian_tunado_3.0.md"
DATA=$(date '+%Y-%m-%d %H:%M:%S')

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
TOTAL_CHECKS=0
PASS=0
FAIL=0
WARN=0

# Arrays para armazenar resultados
declare -a RESULTADOS_PASS
declare -a RESULTADOS_FAIL
declare -a RESULTADOS_WARN

# Funcao de check
check() {
    local descricao="$1"
    local comando="$2"
    local esperado="$3"
    local severidade="${4:-FAIL}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$comando" &>/dev/null; then
        PASS=$((PASS + 1))
        RESULTADOS_PASS+=("| $descricao | $esperado | PASS |")
        echo -e "${GREEN}✅${NC} $descricao"
        return 0
    else
        if [ "$severidade" == "FAIL" ]; then
            FAIL=$((FAIL + 1))
            RESULTADOS_FAIL+=("| $descricao | $esperado | FAIL |")
            echo -e "${RED}❌${NC} $descricao"
        else
            WARN=$((WARN + 1))
            RESULTADOS_WARN+=("| $descricao | $esperado | WARN |")
            echo -e "${YELLOW}⚠️${NC} $descricao"
        fi
        return 1
    fi
}

# Inicio
clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AUDITORIA DEBIAN TUNADO 3.0 - NIVEL FLORENCE              ║${NC}"
echo -e "${BLUE}║     Verificando cada detalhe do documento oficial...          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ==============================================================================
# 1. HARDWARE E SISTEMA BASE
# ==============================================================================
echo -e "${BLUE}▶ 1. HARDWARE E SISTEMA BASE${NC}"

check "Hardware: Lenovo 310-15ISK detectado" \
    "dmidecode -s system-product-name 2>/dev/null | grep -iq '310-15ISK'" \
    "Lenovo 310-15ISK" "WARN"

check "CPU: Intel i5-6200U (Skylake)" \
    "lscpu | grep -iq '6200U'" \
    "i5-6200U @ 2.30GHz" "FAIL"

check "RAM: 8GB disponivel" \
    "[ \$(free -m | awk '/^Mem:/{print \$2}') -ge 7500 ]" \
    "8GB DDR4" "FAIL"

check "SSD: 480GB detectado" \
    "lsblk -d -o SIZE,MODEL 2>/dev/null | grep -q '480.*SanDisk'" \
    "480GB SanDisk SSD" "WARN"

check "UEFI mode ativo" \
    "[ -d /sys/firmware/efi ]" \
    "UEFI (nao Legacy)" "FAIL"

check "OS: Debian 12 (bookworm)" \
    "grep -q 'bookworm' /etc/os-release" \
    "Debian GNU/Linux 12" "FAIL"

check "Hostname: clipfusion" \
    "[ \"\$(hostname)\" = 'clipfusion' ]" \
    "clipfusion" "WARN"

# ==============================================================================
# 2. KERNEL E PARAMETROS GRUB (CRITICO)
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 2. KERNEL E PARAMETROS GRUB${NC}"

CMDLINE=$(cat /proc/cmdline 2>/dev/null || echo "")

check "Kernel: i915.enable_guc=3 (GuC+HuC ativos)" \
    "grep -q 'i915.enable_guc=3' /proc/cmdline" \
    "enable_guc=3 (encode QSV completo)" "FAIL"

check "Kernel: intel_pstate=active" \
    "grep -q 'intel_pstate=active' /proc/cmdline" \
    "intel_pstate=active" "FAIL"

check "Kernel: intel_pstate.max_perf_pct=100" \
    "grep -q 'intel_pstate.max_perf_pct=100' /proc/cmdline" \
    "max_perf_pct=100" "FAIL"

check "Kernel: mitigations=off" \
    "grep -q 'mitigations=off' /proc/cmdline" \
    "mitigations=off (performance)" "WARN"

check "Kernel: i915.enable_fbc=1" \
    "grep -q 'i915.enable_fbc=1' /proc/cmdline" \
    "enable_fbc=1 (frame buffer compression)" "FAIL"

check "Kernel: i915.enable_psr=0" \
    "grep -q 'i915.enable_psr=0' /proc/cmdline" \
    "enable_psr=0 (Panel Self Refresh off)" "FAIL"

check "Kernel: i915.fastboot=1" \
    "grep -q 'i915.fastboot=1' /proc/cmdline" \
    "fastboot=1" "FAIL"

check "Kernel: i915.modeset=1" \
    "grep -q 'i915.modeset=1' /proc/cmdline" \
    "modeset=1" "FAIL"

check "Kernel: modprobe.blacklist NVIDIA completo" \
    "grep -q 'modprobe.blacklist=nouveau' /proc/cmdline" \
    "blacklist completo NVIDIA no cmdline" "FAIL"

check "Kernel: processor.max_cstate=5" \
    "grep -q 'processor.max_cstate=5' /proc/cmdline" \
    "max_cstate=5 (evita latencia C6+)" "WARN"

check "Kernel: intel_iommu=on iommu=pt" \
    "grep -q 'intel_iommu=on' /proc/cmdline && grep -q 'iommu=pt' /proc/cmdline" \
    "IOMMU ativo pass-through" "WARN"

check "Kernel: nmi_watchdog=0 nowatchdog" \
    "grep -q 'nmi_watchdog=0' /proc/cmdline" \
    "watchdogs desabilitados" "WARN"

check "Kernel: tsc=reliable clocksource=tsc" \
    "grep -q 'tsc=reliable' /proc/cmdline" \
    "TSC como clocksource" "WARN"

check "Kernel: hpet=disable" \
    "grep -q 'hpet=disable' /proc/cmdline" \
    "HPET desabilitado" "WARN"

check "Kernel: audit=0" \
    "grep -q 'audit=0' /proc/cmdline" \
    "audit desabilitado (menos overhead)" "WARN"

# ==============================================================================
# 3. NVIDIA BLOQUEIO TOTAL
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 3. NVIDIA 920MX - BLOQUEIO TOTAL${NC}"

check "Arquivo: /etc/modprobe.d/blacklist-nvidia.conf existe" \
    "[ -f /etc/modprobe.d/blacklist-nvidia.conf ]" \
    "blacklist-nvidia.conf presente" "FAIL"

check "Blacklist: nouveau listado" \
    "grep -q '^blacklist nouveau' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null" \
    "blacklist nouveau" "FAIL"

check "Blacklist: nvidia listado" \
    "grep -q '^blacklist nvidia\$' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null" \
    "blacklist nvidia" "FAIL"

check "Blacklist: nvidia_drm listado" \
    "grep -q '^blacklist nvidia_drm' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null" \
    "blacklist nvidia_drm" "FAIL"

check "Blacklist: nvidia_modeset listado" \
    "grep -q '^blacklist nvidia_modeset' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null" \
    "blacklist nvidia_modeset" "FAIL"

check "Blacklist: options nouveau modeset=0" \
    "grep -q '^options nouveau modeset=0' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null" \
    "options nouveau modeset=0" "FAIL"

check "Modulo: nouveau NAO carregado" \
    "! lsmod | grep -q '^nouveau'" \
    "nouveau nao esta na RAM" "FAIL"

check "Modulo: nvidia NAO carregado" \
    "! lsmod | grep -q '^nvidia'" \
    "nvidia nao esta na RAM" "FAIL"

check "Temperatura: CPU < 50C (NVIDIA desabilitada)" \
    "command -v sensors >/dev/null 2>&1 && TEMP=\$(sensors 2>/dev/null | grep 'Core 0' | head -1 | awk '{print \$3}' | tr -d '+°C.' | cut -d. -f1 2>/dev/null); [ -n \"\$TEMP\" ] && [ \$TEMP -lt 50 ] 2>/dev/null" \
    "< 50C (NVIDIA desabilitada economiza -10W)" "WARN"

# ==============================================================================
# 4. INTEL HD 520 - VA-API E FIRMWARE
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 4. INTEL HD 520 - VA-API QSV${NC}"

check "Firmware: DMC presente (skl_dmc)" \
    "ls /lib/firmware/i915/skl_dmc_*.bin 2>/dev/null | grep -q ." \
    "skl_dmc_ver*.bin" "FAIL"

check "Firmware: GuC presente (skl_guc)" \
    "ls /lib/firmware/i915/skl_guc_*.bin 2>/dev/null | grep -q ." \
    "skl_guc_*.bin" "FAIL"

check "Firmware: HuC presente (skl_huc)" \
    "ls /lib/firmware/i915/skl_huc_*.bin 2>/dev/null | grep -q ." \
    "skl_huc_*.bin" "FAIL"

check "Device: /dev/dri/renderD128 existe" \
    "[ -e /dev/dri/renderD128 ]" \
    "renderD128 (aceleracao disponivel)" "FAIL"

check "Pacote: intel-media-va-driver-non-free instalado" \
    "dpkg -l 2>/dev/null | grep -q 'intel-media-va-driver-non-free'" \
    "driver iHD (nao i965)" "FAIL"

check "Pacote: i965-va-driver-shaders instalado" \
    "dpkg -l 2>/dev/null | grep -q 'i965-va-driver-shaders'" \
    "shaders i965 (fallback)" "WARN"

check "Pacote: vainfo instalado" \
    "command -v vainfo >/dev/null 2>&1" \
    "vainfo disponivel" "FAIL"

check "VA-API: Driver iHD ativo (nao i965)" \
    "vainfo 2>&1 | grep -q 'Driver version: Intel iHD'" \
    "Intel iHD driver" "FAIL"

check "VA-API: H.264 encode disponivel" \
    "vainfo 2>&1 | grep -q 'VAProfileH264Main.*VAEntrypointEncSlice'" \
    "VAEntrypointEncSlice (encode HW)" "FAIL"

check "Variavel: LIBVA_DRIVER_NAME=iHD" \
    "grep -q 'LIBVA_DRIVER_NAME=iHD' /etc/environment 2>/dev/null || find /home -maxdepth 2 -name '.bashrc' -exec grep -q 'LIBVA_DRIVER_NAME=iHD' {} \\; 2>/dev/null" \
    "export LIBVA_DRIVER_NAME=iHD" "WARN"

check "Variavel: LIBVA_DRIVERS_PATH definido" \
    "grep -q 'LIBVA_DRIVERS_PATH' /etc/environment 2>/dev/null || find /home -maxdepth 2 -name '.bashrc' -exec grep -q 'LIBVA_DRIVERS_PATH' {} \\; 2>/dev/null" \
    "export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri" "WARN"

# ==============================================================================
# 5. BTRFS - 6 SUBVOLUMES E MOUNT OPTIONS
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 5. BTRFS - SISTEMA DE ARQUIVOS${NC}"

check "Filesystem: Root e BTRFS" \
    "findmnt -n -o FSTYPE / 2>/dev/null | grep -q 'btrfs'" \
    "btrfs (nao ext4)" "FAIL"

check "Subvolume: @ (raiz) existe" \
    "btrfs subvolume list / 2>/dev/null | grep -q 'path @\$'" \
    "subvol=@" "FAIL"

check "Subvolume: @home existe" \
    "btrfs subvolume list / 2>/dev/null | grep -q 'path @home'" \
    "subvol=@home" "FAIL"

check "Subvolume: @docker existe" \
    "btrfs subvolume list / 2>/dev/null | grep -q 'path @docker'" \
    "subvol=@docker" "FAIL"

check "Subvolume: @postgres existe" \
    "btrfs subvolume list / 2>/dev/null | grep -q 'path @postgres'" \
    "subvol=@postgres" "FAIL"

check "Subvolume: @var existe" \
    "btrfs subvolume list / 2>/dev/null | grep -q 'path @var'" \
    "subvol=@var" "FAIL"

check "Subvolume: @snapshots existe" \
    "btrfs subvolume list / 2>/dev/null | grep -q 'path @snapshots'" \
    "subvol=@snapshots" "FAIL"

check "Total: 6 subvolumes presentes" \
    "[ \$(btrfs subvolume list / 2>/dev/null | wc -l) -ge 6 ]" \
    "6 subvolumes" "FAIL"

check "Mount /: compress=zstd:3" \
    "findmnt -n -o OPTIONS / 2>/dev/null | grep -q 'compress=zstd:3'" \
    "compress=zstd:3 (maxima compressao)" "FAIL"

check "Mount /: noatime" \
    "findmnt -n -o OPTIONS / 2>/dev/null | grep -q 'noatime'" \
    "noatime (sem writes de atime)" "FAIL"

check "Mount /: ssd" \
    "findmnt -n -o OPTIONS / 2>/dev/null | grep -q 'ssd'" \
    "ssd (otimizacoes SSD)" "FAIL"

check "Mount /: discard=async" \
    "findmnt -n -o OPTIONS / 2>/dev/null | grep -q 'discard=async'" \
    "discard=async (TRIM async)" "FAIL"

check "Mount /: space_cache=v2" \
    "findmnt -n -o OPTIONS / 2>/dev/null | grep -q 'space_cache=v2'" \
    "space_cache=v2" "FAIL"

check "Mount: /home em subvolume separado @home" \
    "findmnt -n -o OPTIONS /home 2>/dev/null | grep -q 'subvol=@home'" \
    "/home -> @home" "FAIL"

check "Mount: /var/lib/docker com nodatacow" \
    "findmnt -n -o OPTIONS /var/lib/docker 2>/dev/null | grep -q 'nodatacow'" \
    "nodatacow (desabilita COW para Docker)" "WARN"

check "Mount: /var/lib/postgresql com nodatacow" \
    "findmnt -n -o OPTIONS /var/lib/postgresql 2>/dev/null | grep -q 'nodatacow'" \
    "nodatacow (desabilita COW para PostgreSQL)" "WARN"

check "BTRFS saudavel: sem erros" \
    "btrfs device stats / 2>/dev/null | grep -q 'errors 0'" \
    "0 erros de checksum/leitura/escrita" "FAIL"

# ==============================================================================
# 6. ZRAM - 4GB ZSTD
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 6. ZRAM - MEMORIA COMPRIMIDA${NC}"

check "Pacote: zram-tools instalado" \
    "dpkg -l 2>/dev/null | grep -q 'zram-tools'" \
    "zram-tools" "FAIL"

check "Config: /etc/default/zramswap existe" \
    "[ -f /etc/default/zramswap ]" \
    "/etc/default/zramswap" "FAIL"

check "ZRAM: ALGO=zstd" \
    "grep -q '^ALGO=zstd' /etc/default/zramswap 2>/dev/null" \
    "ALGO=zstd (3:1 compressao vs 2:1 lz4)" "FAIL"

check "ZRAM: SIZE=4096" \
    "grep -q '^SIZE=4096' /etc/default/zramswap 2>/dev/null" \
    "SIZE=4096 (4GB = 50% de 8GB)" "FAIL"

check "ZRAM: PRIORITY=100" \
    "grep -q '^PRIORITY=100' /etc/default/zramswap 2>/dev/null" \
    "PRIORITY=100 (usa antes do swap SSD)" "FAIL"

check "Servico: zramswap ativo" \
    "systemctl is-active zramswap >/dev/null 2>&1" \
    "systemctl status zramswap = active" "FAIL"

check "Device: /dev/zram0 existe e ativo" \
    "swapon --show 2>/dev/null | grep -q 'zram0'" \
    "/dev/zram0 partition 4G" "FAIL"

# ==============================================================================
# 7. SWAP FILE - 2GB SSD
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 7. SWAP FILE NO SSD${NC}"

check "Diretorio: /swap existe" \
    "[ -d /swap ]" \
    "/swap (diretorio dedicado)" "FAIL"

check "Swapfile: /swap/swapfile existe" \
    "[ -f /swap/swapfile ]" \
    "/swap/swapfile" "FAIL"

check "Swapfile: tamanho 2GB" \
    "[ \$(stat -c%s /swap/swapfile 2>/dev/null || echo 0) -ge 2000000000 ]" \
    "2GB (2048MB)" "FAIL"

check "Swapfile: permissoes 600" \
    "[ \$(stat -c%a /swap/swapfile 2>/dev/null || echo 0) -eq 600 ]" \
    "chmod 600 (somente root)" "FAIL"

check "Swapfile: nodatacow ativo (chattr +C)" \
    "lsattr /swap 2>/dev/null | grep -q 'C'" \
    "chattr +C /swap (desabilita COW antes do dd)" "FAIL"

check "Swap: ativado com pri=50" \
    "swapon --show 2>/dev/null | grep -q 'swapfile.*50'" \
    "pri=50 (menor que ZRAM 100)" "FAIL"

check "Fstab: swapfile configurado" \
    "grep -q '/swap/swapfile' /etc/fstab" \
    "/swap/swapfile none swap sw,pri=50 0 0" "FAIL"

# ==============================================================================
# 8. SYSCTL - PARAMETROS DE PERFORMANCE
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 8. SYSCTL - KERNEL TUNING${NC}"

check "Arquivo: /etc/sysctl.d/99-performance.conf existe" \
    "[ -f /etc/sysctl.d/99-performance.conf ]" \
    "99-performance.conf" "FAIL"

check "Sysctl: kernel.sched_migration_cost_ns=5000000" \
    "grep -q 'sched_migration_cost_ns=5000000' /etc/sysctl.d/99-performance.conf 2>/dev/null && [ \"\$(sysctl -n kernel.sched_migration_cost_ns 2>/dev/null)\" = \"5000000\" ]" \
    "migration_cost_ns=5ms" "WARN"

check "Sysctl: kernel.sched_autogroup_enabled=1" \
    "grep -q 'sched_autogroup_enabled=1' /etc/sysctl.d/99-performance.conf 2>/dev/null && [ \"\$(sysctl -n kernel.sched_autogroup_enabled 2>/dev/null)\" = \"1\" ]" \
    "autogroup_enabled=1" "WARN"

check "Sysctl: vm.swappiness=150" \
    "[ \"\$(sysctl -n vm.swappiness 2>/dev/null)\" = \"150\" ]" \
    "swappiness=150 (prioriza ZRAM)" "FAIL"

check "Sysctl: vm.vfs_cache_pressure=50" \
    "[ \"\$(sysctl -n vm.vfs_cache_pressure 2>/dev/null)\" = \"50\" ]" \
    "vfs_cache_pressure=50" "WARN"

check "Sysctl: vm.overcommit_memory=2" \
    "[ \"\$(sysctl -n vm.overcommit_memory 2>/dev/null)\" = \"2\" ]" \
    "overcommit_memory=2 (controlado)" "FAIL"

check "Sysctl: vm.overcommit_ratio=80" \
    "[ \"\$(sysctl -n vm.overcommit_ratio 2>/dev/null)\" = \"80\" ]" \
    "overcommit_ratio=80" "WARN"

check "Sysctl: net.ipv4.tcp_congestion_control=bbr" \
    "[ \"\$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)\" = \"bbr\" ]" \
    "tcp_congestion_control=bbr" "WARN"

check "Sysctl: net.core.default_qdisc=fq_codel" \
    "[ \"\$(sysctl -n net.core.default_qdisc 2>/dev/null)\" = \"fq_codel\" ]" \
    "default_qdisc=fq_codel" "WARN"

check "Sysctl: fs.inotify.max_user_watches=1048576" \
    "[ \"\$(sysctl -n fs.inotify.max_user_watches 2>/dev/null)\" = \"1048576\" ]" \
    "max_user_watches=1048576 (File Watcher)" "WARN"

# ==============================================================================
# 9. TDP UNLOCK - i5-6200U
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 9. TDP UNLOCK - PERFORMANCE CPU${NC}"

check "Pacote: linux-cpupower instalado" \
    "dpkg -l 2>/dev/null | grep -q 'linux-cpupower'" \
    "linux-cpupower" "FAIL"

check "Pacote: msr-tools instalado" \
    "dpkg -l 2>/dev/null | grep -q 'msr-tools'" \
    "msr-tools (wrmsr/rdmsr)" "FAIL"

check "Modulo: msr carregado" \
    "lsmod | grep -q '^msr'" \
    "msr module" "FAIL"

check "Script: /usr/local/bin/tdp-unlock.sh existe" \
    "[ -f /usr/local/bin/tdp-unlock.sh ]" \
    "tdp-unlock.sh" "FAIL"

check "Script: PL1=20W (0x00dc8004dc8000)" \
    "grep -q '0x00dc8004dc8000' /usr/local/bin/tdp-unlock.sh 2>/dev/null" \
    "wrmsr 0x610 0x00dc8004dc8000 (PL1=20W, PL2=25W)" "FAIL"

check "Script: Turbo 2.7GHz (0x1B1B1B1B1B1B1B1B)" \
    "grep -q '0x1B1B1B1B1B1B1B1B' /usr/local/bin/tdp-unlock.sh 2>/dev/null" \
    "wrmsr 0x1ad 0x1B... (27x = 2.7GHz)" "FAIL"

check "Servico: tdp-unlock.service existe" \
    "[ -f /etc/systemd/system/tdp-unlock.service ]" \
    "tdp-unlock.service" "FAIL"

check "Servico: tdp-unlock.service habilitado" \
    "systemctl is-enabled tdp-unlock.service >/dev/null 2>&1" \
    "systemctl enable tdp-unlock.service" "FAIL"

# ==============================================================================
# 10. SERVICOS E THERMAL
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 10. SERVICOS THERMAL E MANUTENCAO${NC}"

check "Pacote: thermald instalado" \
    "dpkg -l 2>/dev/null | grep -q '^ii.*thermald'" \
    "thermald (Intel DPTF)" "FAIL"

check "Servico: thermald ativo" \
    "systemctl is-active thermald >/dev/null 2>&1" \
    "systemctl status thermald = active" "FAIL"

check "Servico: thermald habilitado" \
    "systemctl is-enabled thermald >/dev/null 2>&1" \
    "systemctl enable thermald" "FAIL"

check "Servico: fstrim.timer habilitado" \
    "systemctl is-enabled fstrim.timer >/dev/null 2>&1" \
    "fstrim.timer (TRIM semanal)" "FAIL"

check "Servico: fstrim.timer ativo" \
    "systemctl is-active fstrim.timer >/dev/null 2>&1" \
    "fstrim.timer running" "FAIL"

check "Governor: performance (via cpupower)" \
    "cpupower frequency-info 2>/dev/null | grep -q 'governor \"performance\"' || { [ -f /etc/default/cpupower ] && grep -q 'GOVERNOR=\"performance\"' /etc/default/cpupower; }" \
    "cpupower frequency-set -g performance" "WARN"

# ==============================================================================
# 11. DOCKER E CONTAINERS
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 11. DOCKER${NC}"

check "Docker: instalado" \
    "command -v docker >/dev/null 2>&1" \
    "docker" "WARN"

check "Docker: servico ativo" \
    "systemctl is-active docker >/dev/null 2>&1" \
    "systemctl status docker = active" "WARN"

check "Docker: storage-driver=overlay2" \
    "docker info 2>/dev/null | grep -q 'Storage Driver: overlay2'" \
    "overlay2 (nao btrfs nativo)" "WARN"

check "Docker: /etc/docker/daemon.json existe" \
    "[ -f /etc/docker/daemon.json ]" \
    "daemon.json configurado" "WARN"

check "Docker: log-opts max-size=10m" \
    "grep -q '\"max-size\": \"10m\"' /etc/docker/daemon.json 2>/dev/null" \
    "log max-size=10m" "WARN"

check "Docker: default-ulimits nofile" \
    "grep -q 'nofile' /etc/docker/daemon.json 2>/dev/null" \
    "ulimits nofile=1048576" "WARN"

check "Docker: live-restore=true" \
    "grep -q 'live-restore.*true' /etc/docker/daemon.json 2>/dev/null" \
    "live-restore=true" "WARN"

check "Docker: buildkit habilitado" \
    "grep -q 'buildkit.*true' /etc/docker/daemon.json 2>/dev/null" \
    "features.buildkit=true" "WARN"

check "Docker: systemd override com MemoryMax=5G" \
    "[ -f /etc/systemd/system/docker.service.d/override.conf ] && grep -q 'MemoryMax=5G' /etc/systemd/system/docker.service.d/override.conf" \
    "MemoryMax=5G limit" "WARN"

check "Docker: CPUQuota=350%" \
    "[ -f /etc/systemd/system/docker.service.d/override.conf ] && grep -q 'CPUQuota=350%' /etc/systemd/system/docker.service.d/override.conf" \
    "CPUQuota=350% (3.5 cores)" "WARN"

# ==============================================================================
# 12. I3WM E INTERFACE GRAFICA
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 12. INTERFACE GRAFICA (i3wm)${NC}"

check "Pacote: i3-wm instalado" \
    "dpkg -l 2>/dev/null | grep -q 'i3-wm'" \
    "i3-wm" "WARN"

check "Pacote: lightdm instalado" \
    "dpkg -l 2>/dev/null | grep -q 'lightdm'" \
    "lightdm" "WARN"

check "Servico: lightdm habilitado" \
    "systemctl is-enabled lightdm >/dev/null 2>&1" \
    "systemctl enable lightdm" "WARN"

check "Config: ~/.config/i3/config existe" \
    "find /home -maxdepth 3 -name 'config' -path '*/.config/i3/config' 2>/dev/null | grep -q ." \
    "i3 config personalizado" "WARN"

check "Config: gaps inner 0 (performance)" \
    "find /home -maxdepth 3 -name 'config' -path '*/.config/i3/config' -exec grep -q 'gaps inner 0' {} \\; 2>/dev/null" \
    "gaps inner 0" "WARN"

# ==============================================================================
# 13. USUARIO E PERMISSOES
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 13. USUARIO E GRUPOS${NC}"

check "Usuario: highlander existe" \
    "id highlander >/dev/null 2>&1" \
    "highlander" "FAIL"

check "Grupo: highlander em video" \
    "id highlander 2>/dev/null | grep -q '(video)'" \
    "usermod -aG video highlander" "FAIL"

check "Grupo: highlander em render" \
    "id highlander 2>/dev/null | grep -q '(render)'" \
    "usermod -aG render highlander" "FAIL"

check "Grupo: highlander em docker" \
    "id highlander 2>/dev/null | grep -q '(docker)'" \
    "usermod -aG docker highlander" "WARN"

# ==============================================================================
# 14. SCRIPTS E ALIASES
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 14. SCRIPTS DO SISTEMA${NC}"

check "Script: /usr/local/bin/validate-system.sh existe" \
    "[ -f /usr/local/bin/validate-system.sh ]" \
    "validate-system.sh" "WARN"

check "Script: /usr/local/bin/snapshot-weekly.sh existe" \
    "[ -f /usr/local/bin/snapshot-weekly.sh ]" \
    "snapshot-weekly.sh" "WARN"

check "Script: /usr/local/bin/monitor-system.sh existe" \
    "[ -f /usr/local/bin/monitor-system.sh ]" \
    "monitor-system.sh" "WARN"

check "Alias: validate no .bashrc" \
    "find /home -maxdepth 2 -name '.bashrc' -exec grep -q 'alias validate=' {} \\; 2>/dev/null" \
    "alias validate='sudo /usr/local/bin/validate-system.sh'" "WARN"

check "Alias: ll='ls -lah'" \
    "find /home -maxdepth 2 -name '.bashrc' -exec grep -q \"alias ll='ls -lah'\" {} \\; 2>/dev/null" \
    "alias ll='ls -lah'" "WARN"

# ==============================================================================
# 15. ESTRUTURA /DATA
# ==============================================================================
echo ""
echo -e "${BLUE}▶ 15. ESTRUTURA DE DADOS${NC}"

check "Diretorio: /data existe" \
    "[ -d /data ]" \
    "/data" "WARN"

check "Diretorio: /data/clipfusion/media/raw" \
    "[ -d /data/clipfusion/media/raw ]" \
    "/data/clipfusion/media/raw" "WARN"

check "Diretorio: /data/clipfusion/media/processed" \
    "[ -d /data/clipfusion/media/processed ]" \
    "/data/clipfusion/media/processed" "WARN"

check "Diretorio: /data/clipfusion/exports" \
    "[ -d /data/clipfusion/exports ]" \
    "/data/clipfusion/exports" "WARN"

check "Diretorio: /data/cache/whisper" \
    "[ -d /data/cache/whisper ]" \
    "/data/cache/whisper" "WARN"

check "Permissoes: /data pertence a highlander" \
    "stat -c '%U' /data 2>/dev/null | grep -q 'highlander'" \
    "chown highlander:highlander /data" "WARN"

# ==============================================================================
# GERAR RELATORIO MARKDOWN
# ==============================================================================
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    GERANDO RELATORIO...                         ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

# Calcular percentual
PERCENTUAL=$(echo "scale=1; ($PASS / $TOTAL_CHECKS) * 100" | bc -l 2>/dev/null || echo "0")

cat > "$RELATORIO" << EOF
# 📊 Auditoria Debian Tunado 3.0 - Nivel Florence

**Data:** $DATA  
**Hostname:** $(hostname)  
**Kernel:** $(uname -r)  

---

## 📈 Resumo Executivo

| Metrica | Valor |
|---------|-------|
| **Total de verificacoes** | $TOTAL_CHECKS |
| **✅ PASS (Correto)** | $PASS |
| **❌ FAIL (Critico - deve corrigir)** | $FAIL |
| **⚠️ WARN (Recomendado - pode corrigir)** | $WARN |
| **Percentual de conformidade** | ${PERCENTUAL}% |

### 🎯 Status Geral
$(if [ $FAIL -eq 0 ]; then 
    echo "✅ **SISTEMA 100% CONFORME** - Pronto para ClipFusion!"
elif [ $FAIL -le 5 ]; then 
    echo "⚠️ **SISTEMA PARCIALMENTE CONFIGURADO** - Alguns ajustes necessarios"
else 
    echo "❌ **SISTEMA NAO CONFIGURADO** - Requer atencao significativa"
fi)

---

## ❌ CRITICO - Deve corrigir imediatamente ($FAIL itens)

| Item | Esperado | Status |
|------|----------|--------|
$(printf "%s\n" "${RESULTADOS_FAIL[@]}" 2>/dev/null || echo "| Nenhum | - | - |")

---

## ⚠️ RECOMENDADO - Pode corrigir ($WARN itens)

| Item | Esperado | Status |
|------|----------|--------|
$(printf "%s\n" "${RESULTADOS_WARN[@]}" 2>/dev/null || echo "| Nenhum | - | - |")

---

## ✅ CORRETO - Configurado conforme especificacao ($PASS itens)

| Item | Esperado | Status |
|------|----------|--------|
$(printf "%s\n" "${RESULTADOS_PASS[@]}" 2>/dev/null || echo "| Nenhum | - | - |")

---

*Relatorio gerado automaticamente*
*Referencia: debian_tunado_3.0_OFICIAL.docx*
EOF

echo ""
echo -e "${GREEN}✅ Relatorio salvo em:${NC} $RELATORIO"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    RESUMO DA AUDITORIA                         ║"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  ✅ PASS:  %-51s║\n" "$PASS"
printf "║  ❌ FAIL:  %-51s║\n" "$FAIL $(if [ $FAIL -gt 0 ]; then echo "(CRITICO)"; fi)"
printf "║  ⚠️  WARN:  %-51s║\n" "$WARN"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 SISTEMA 100% CONFORME! Pronto para ClipFusion.${NC}"
elif [ $FAIL -le 5 ]; then
    echo -e "${YELLOW}⚠️  Sistema parcialmente configurado. Corrija os FAILs.${NC}"
else
    echo -e "${RED}❌ Sistema requer atencao significativa.${NC}"
fi

echo ""
echo "Para ver o relatorio completo:"
echo "  cat $RELATORIO"
echo ""
