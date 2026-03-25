#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════
# DIAGNOSTIC COMPLETO - DEBIAN TUNADO 3.0 OFICIAL
# Baseado em: debian_tunado_3_0_OFICIAL.docx
# Hardware: Lenovo 310-15ISK • i5-6200U • Intel HD 520 • 8GB RAM • SSD 480GB
# ══════════════════════════════════════════════════════════════════════════

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
    
    if eval "$cmd" &>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}✅${NC} $desc"
        return 0
    else
        if [ "$severity" = "FAIL" ]; then
            FAIL=$((FAIL + 1))
            echo -e "  ${RED}❌${NC} $desc"
        else
            WARN=$((WARN + 1))
            echo -e "  ${YELLOW}⚠️${NC} $desc"
        fi
        return 1
    fi
}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     DIAGNÓSTICO DEBIAN TUNADO 3.0 - OFICIAL                   ║"
echo "║     Hardware: i5-6200U • Intel HD 520 • 8GB • SSD 480GB       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 1. HARDWARE E SISTEMA BASE
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 1. HARDWARE E SISTEMA BASE${NC}"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "Kernel: $(uname -r)"
echo "RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo "Uptime: $(uptime -p)"
echo ""

check "CPU: Intel i5-6200U" "lscpu | grep -q '6200U'"
check "RAM: 8GB disponível" "[ \$(free -m | awk '/^Mem:/{print \$2}') -ge 7500 ]"
check "OS: Debian 12 (bookworm)" "grep -q 'bookworm' /etc/os-release"
check "UEFI mode ativo" "[ -d /sys/firmware/efi ]"
check "Hostname: Highlander-serv ou clipfusion" "hostname | grep -qE '(Highlander|clipfusion)'" "WARN"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 2. BTRFS - 6 SUBVOLUMES OBRIGATÓRIOS
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 2. BTRFS - 6 SUBVOLUMES${NC}"
if btrfs subvolume list / &>/dev/null; then
    SUBVOL_COUNT=$(btrfs subvolume list / | wc -l)
    if [ $SUBVOL_COUNT -ge 6 ]; then
        echo -e "  ${GREEN}✅ $SUBVOL_COUNT subvolumes encontrados${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}❌ Apenas $SUBVOL_COUNT subvolumes (esperado: 6)${NC}"
        FAIL=$((FAIL + 1))
    fi
    echo "  Subvolumes:"
    btrfs subvolume list / | awk '{printf "    - %s\n", $9}'
else
    echo -e "  ${RED}❌ Sistema NÃO é BTRFS${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

check "Mount /: compress=zstd:3" "findmnt -n -o OPTIONS / | grep -q 'compress=zstd:3'"
check "Mount /: noatime" "findmnt -n -o OPTIONS / | grep -q 'noatime'"
check "Mount /: ssd" "findmnt -n -o OPTIONS / | grep -q 'ssd'"
check "Mount /: discard=async" "findmnt -n -o OPTIONS / | grep -q 'discard=async'"
check "Mount /: space_cache=v2" "findmnt -n -o OPTIONS / | grep -q 'space_cache=v2'"
check "BTRFS saudável (sem erros)" "btrfs device stats / 2>/dev/null | grep -q 'errors 0'"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 3. KERNEL PARAMS (GRUB) - TODOS OS 17 PARAMS DO DOCUMENTO
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 3. KERNEL PARAMS (GRUB)${NC}"
check "i915.enable_guc=3 (GuC+HuC)" "grep -q 'i915.enable_guc=3' /proc/cmdline"
check "intel_pstate=active" "grep -q 'intel_pstate=active' /proc/cmdline"
check "intel_pstate.max_perf_pct=100" "grep -q 'intel_pstate.max_perf_pct=100' /proc/cmdline"
check "mitigations=off" "grep -q 'mitigations=off' /proc/cmdline" "WARN"
check "i915.enable_fbc=1" "grep -q 'i915.enable_fbc=1' /proc/cmdline"
check "i915.enable_psr=0" "grep -q 'i915.enable_psr=0' /proc/cmdline"
check "i915.fastboot=1" "grep -q 'i915.fastboot=1' /proc/cmdline"
check "i915.modeset=1" "grep -q 'i915.modeset=1' /proc/cmdline"
check "modprobe.blacklist NVIDIA" "grep -q 'modprobe.blacklist=nouveau' /proc/cmdline"
check "processor.max_cstate=5" "grep -q 'processor.max_cstate=5' /proc/cmdline" "WARN"
check "intel_iommu=on" "grep -q 'intel_iommu=on' /proc/cmdline" "WARN"
check "iommu=pt" "grep -q 'iommu=pt' /proc/cmdline" "WARN"
check "nmi_watchdog=0" "grep -q 'nmi_watchdog=0' /proc/cmdline" "WARN"
check "tsc=reliable" "grep -q 'tsc=reliable' /proc/cmdline" "WARN"
check "clocksource=tsc" "grep -q 'clocksource=tsc' /proc/cmdline" "WARN"
check "hpet=disable" "grep -q 'hpet=disable' /proc/cmdline" "WARN"
check "audit=0" "grep -q 'audit=0' /proc/cmdline" "WARN"
check "msr.allow_writes=on (TDP)" "grep -q 'msr.allow_writes=on' /proc/cmdline"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 4. NVIDIA 920MX - BLOQUEIO TOTAL
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 4. NVIDIA 920MX - BLOQUEIO TOTAL${NC}"
check "Arquivo blacklist-nvidia.conf" "[ -f /etc/modprobe.d/blacklist-nvidia.conf ]"
check "Blacklist: nouveau" "grep -q '^blacklist nouveau' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "Blacklist: nvidia" "grep -q '^blacklist nvidia\$' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "Blacklist: nvidia_drm" "grep -q '^blacklist nvidia_drm' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "Blacklist: nvidia_modeset" "grep -q '^blacklist nvidia_modeset' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "Options nouveau modeset=0" "grep -q '^options nouveau modeset=0' /etc/modprobe.d/blacklist-nvidia.conf 2>/dev/null"
check "Módulo nouveau NÃO carregado" "! lsmod | grep -q '^nouveau'"
check "Módulo nvidia NÃO carregado" "! lsmod | grep -q '^nvidia'"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 5. INTEL HD 520 - VA-API QSV
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 5. INTEL HD 520 - VA-API QSV${NC}"
check "Firmware DMC (skl_dmc)" "ls /lib/firmware/i915/skl_dmc_*.bin 2>/dev/null | grep -q ."
check "Firmware GuC (skl_guc)" "ls /lib/firmware/i915/skl_guc_*.bin 2>/dev/null | grep -q ."
check "Firmware HuC (skl_huc)" "ls /lib/firmware/i915/skl_huc_*.bin 2>/dev/null | grep -q ."
check "Device /dev/dri/renderD128" "[ -e /dev/dri/renderD128 ]"
check "Pacote intel-media-va-driver-non-free" "dpkg -l 2>/dev/null | grep -q 'intel-media-va-driver-non-free'"
check "Pacote vainfo" "command -v vainfo >/dev/null 2>&1"
check "VA-API Driver iHD ativo" "vainfo 2>&1 | grep -q 'Driver version: Intel iHD'"
check "VA-API H.264 encode" "vainfo 2>&1 | grep -q 'VAProfileH264Main.*VAEntrypointEncSlice'"
check "LIBVA_DRIVER_NAME=iHD" "grep -q 'LIBVA_DRIVER_NAME=iHD' /etc/environment 2>/dev/null || find /home -maxdepth 2 -name '.bashrc' -exec grep -q 'LIBVA_DRIVER_NAME=iHD' {} \\; 2>/dev/null" "WARN"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 6. ZRAM - 4GB ZSTD PRIORITY 100
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 6. ZRAM - 4GB ZSTD${NC}"
check "Arquivo /etc/default/zramswap" "[ -f /etc/default/zramswap ]"
check "ZRAM: ALGO=zstd" "grep -q '^ALGO=zstd' /etc/default/zramswap 2>/dev/null"
check "ZRAM: SIZE=4096" "grep -q '^SIZE=4096' /etc/default/zramswap 2>/dev/null"
check "ZRAM: PRIORITY=100" "grep -q '^PRIORITY=100' /etc/default/zramswap 2>/dev/null"
check "Service zramswap ativo" "systemctl is-active zramswap >/dev/null 2>&1"
check "Device /dev/zram0 ativo" "swapon --show 2>/dev/null | grep -q 'zram0'"
if swapon --show 2>/dev/null | grep -q 'zram0'; then
    echo "  ZRAM Size: $(swapon --show 2>/dev/null | grep zram0 | awk '{print $3}')"
fi
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 7. SWAP FILE - 2GB SSD nodatacow
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 7. SWAP FILE - 2GB SSD${NC}"
check "Diretório /swap" "[ -d /swap ]"
check "Arquivo /swap/swapfile" "[ -f /swap/swapfile ]"
check "Swapfile: tamanho 2GB" "[ \$(stat -c%s /swap/swapfile 2>/dev/null || echo 0) -ge 2000000000 ]"
check "Swapfile: permissões 600" "[ \$(stat -c%a /swap/swapfile 2>/dev/null || echo 0) -eq 600 ]"
check "Swapfile: nodatacow (chattr +C)" "lsattr /swap 2>/dev/null | grep -q 'C'"
check "Swap ativo com pri=50" "swapon --show 2>/dev/null | grep -q 'swapfile.*50'"
check "Fstab: swapfile configurado" "grep -q '/swap/swapfile' /etc/fstab"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 8. SYSCTL - KERNEL TUNING
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 8. SYSCTL - PERFORMANCE${NC}"
check "Arquivo 99-performance.conf" "[ -f /etc/sysctl.d/99-performance.conf ]"
check "vm.swappiness=150" "[ \"\$(sysctl -n vm.swappiness 2>/dev/null)\" = \"150\" ]"
check "vm.overcommit_memory=2" "[ \"\$(sysctl -n vm.overcommit_memory 2>/dev/null)\" = \"2\" ]"
check "vm.overcommit_ratio=80" "[ \"\$(sysctl -n vm.overcommit_ratio 2>/dev/null)\" = \"80\" ]"
check "vm.vfs_cache_pressure=50" "[ \"\$(sysctl -n vm.vfs_cache_pressure 2>/dev/null)\" = \"50\" ]" "WARN"
check "net.ipv4.tcp_congestion_control=bbr" "[ \"\$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)\" = \"bbr\" ]" "WARN"
check "fs.inotify.max_user_watches=1048576" "[ \"\$(sysctl -n fs.inotify.max_user_watches 2>/dev/null)\" = \"1048576\" ]" "WARN"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 9. TDP UNLOCK - i5-6200U 20W/25W
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 9. TDP UNLOCK - i5-6200U${NC}"
check "Pacote msr-tools" "dpkg -l 2>/dev/null | grep -q 'msr-tools'"
check "Módulo msr carregado" "lsmod | grep -q '^msr'"
check "Script /usr/local/bin/tdp-unlock.sh" "[ -f /usr/local/bin/tdp-unlock.sh ]"
check "Script: PL1=20W PL2=25W (0x00dc8004dc8000)" "grep -q '0x00dc8004dc8000' /usr/local/bin/tdp-unlock.sh 2>/dev/null"
check "Script: Turbo 2.7GHz (0x1B1B1B1B1B1B1B1B)" "grep -q '0x1B1B1B1B1B1B1B1B' /usr/local/bin/tdp-unlock.sh 2>/dev/null"
check "Service tdp-unlock.service" "[ -f /etc/systemd/system/tdp-unlock.service ]"
check "Service tdp-unlock habilitado" "systemctl is-enabled tdp-unlock.service >/dev/null 2>&1"
check "Service tdp-unlock ativo" "systemctl is-active tdp-unlock >/dev/null 2>&1"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 10. THERMAL E CPUPOWER
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 10. THERMAL E CPUPOWER${NC}"
check "Pacote thermald" "dpkg -l 2>/dev/null | grep -q '^ii.*thermald'"
check "Service thermald ativo" "systemctl is-active thermald >/dev/null 2>&1"
check "Service thermald habilitado" "systemctl is-enabled thermald >/dev/null 2>&1"
check "Pacote linux-cpupower" "dpkg -l 2>/dev/null | grep -q 'linux-cpupower'"
check "Governor: performance" "cpupower frequency-info 2>/dev/null | grep -q 'governor \"performance\"' || { [ -f /etc/default/cpupower ] && grep -q 'GOVERNOR=\"performance\"' /etc/default/cpupower; }" "WARN"
check "Service fstrim.timer habilitado" "systemctl is-enabled fstrim.timer >/dev/null 2>&1"
check "Service fstrim.timer ativo" "systemctl is-active fstrim.timer >/dev/null 2>&1"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 11. TEMPERATURA E CPU FREQUENCY
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 11. TEMPERATURA E FREQUENCY${NC}"
if command -v sensors >/dev/null 2>&1; then
    echo "  Temperaturas:"
    sensors 2>/dev/null | grep -E "Core|Package" | sed 's/^/    /'
    TEMP=$(sensors 2>/dev/null | grep 'Core 0' | head -1 | awk '{print $3}' | tr -d '+°C.' | cut -d. -f1 2>/dev/null)
    if [ -n "$TEMP" ] && [ "$TEMP" -lt 50 ]; then
        echo -e "    ${GREEN}✅ CPU < 50°C (NVIDIA desabilitada = -10W)${NC}"
        PASS=$((PASS + 1))
    elif [ -n "$TEMP" ]; then
        echo -e "    ${YELLOW}⚠️  CPU temp: ${TEMP}°C${NC}"
        WARN=$((WARN + 1))
    fi
else
    check "sensors instalado" "false" "WARN"
fi
echo ""
echo "  CPU Frequencies:"
grep MHz /proc/cpuinfo | awk '{printf "    %s MHz\n", $4}' | head -4
TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
if [ "$TURBO" = "0" ]; then
    echo -e "    ${GREEN}✅ Turbo habilitado${NC}"
    PASS=$((PASS + 1))
elif [ "$TURBO" = "1" ]; then
    echo -e "    ${RED}❌ Turbo DESABILITADO${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 12. PACOTES INSTALADOS
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 12. PACOTES OBRIGATÓRIOS${NC}"
check "firmware-misc-nonfree" "dpkg -l 2>/dev/null | grep -q 'firmware-misc-nonfree'"
check "intel-microcode" "dpkg -l 2>/dev/null | grep -q 'intel-microcode'"
check "intel-gpu-tools" "dpkg -l 2>/dev/null | grep -q 'intel-gpu-tools'"
check "btrfs-progs" "dpkg -l 2>/dev/null | grep -q 'btrfs-progs'"
check "lm-sensors" "dpkg -l 2>/dev/null | grep -q 'lm-sensors'"
check "zram-tools" "dpkg -l 2>/dev/null | grep -q 'zram-tools'"
check "htop" "command -v htop >/dev/null 2>&1" "WARN"
check "btop" "command -v btop >/dev/null 2>&1" "WARN"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 13. INTERFACE GRÁFICA (OPCIONAL)
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 13. INTERFACE GRÁFICA (OPCIONAL)${NC}"
check "i3wm instalado" "command -v i3 >/dev/null 2>&1" "WARN"
check "lightdm instalado" "dpkg -l 2>/dev/null | grep -q 'lightdm'" "WARN"
check "lightdm habilitado" "systemctl is-enabled lightdm >/dev/null 2>&1" "WARN"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 14. BOOT E EFI
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 14. BOOT E EFI${NC}"
check "EFI montado" "mount | grep -q efi"
check "GRUB instalado no EFI" "[ -f /boot/efi/EFI/debian/grubx64.efi ]"
check "GRUB config existe" "[ -f /boot/grub/grub.cfg ]"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 15. USUÁRIO E GRUPOS
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 15. USUÁRIO E GRUPOS${NC}"
check "highlander existe" "id highlander >/dev/null 2>&1"
check "highlander em video" "id highlander 2>/dev/null | grep -q '(video)'"
check "highlander em render" "id highlander 2>/dev/null | grep -q '(render)'"
echo ""

# ══════════════════════════════════════════════════════════════════════════
# 16. FSTAB
# ══════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}▶ 16. FSTAB${NC}"
FSTAB_BTRFS=$(grep btrfs /etc/fstab 2>/dev/null | wc -l)
if [ $FSTAB_BTRFS -ge 6 ]; then
    echo -e "  ${GREEN}✅ $FSTAB_BTRFS entradas BTRFS no fstab${NC}"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}❌ Apenas $FSTAB_BTRFS entradas BTRFS (esperado: 6)${NC}"
    FAIL=$((FAIL + 1))
fi
echo "  Entradas BTRFS:"
grep btrfs /etc/fstab 2>/dev/null | awk '{printf "    %s -> %s (%s)\n", $1, $2, $4}' | head -6
echo ""

# ══════════════════════════════════════════════════════════════════════════
# RESUMO FINAL
# ══════════════════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    RESUMO FINAL                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
printf "  ${GREEN}✅ PASS:${NC}  %3d\n" $PASS
printf "  ${RED}❌ FAIL:${NC}  %3d (CRÍTICO - deve corrigir)\n" $FAIL
printf "  ${YELLOW}⚠️  WARN:${NC}  %3d (Recomendado)\n" $WARN
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 SISTEMA 100% CONFORME! Pronto para ClipFusion.${NC}"
    exit 0
elif [ $FAIL -le 5 ]; then
    echo -e "${YELLOW}⚠️  Sistema parcialmente configurado. Corrija os FAILs.${NC}"
    exit 1
else
    echo -e "${RED}❌ Sistema requer atenção significativa.${NC}"
    exit 1
fi
