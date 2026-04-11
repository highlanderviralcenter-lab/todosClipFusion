#!/bin/bash
# diagnostic_highlander.sh - Diagnóstico completo do sistema otimizado
# Hardware: Lenovo 310-15ISK • i5-6200U • Intel HD 520 • 8GB RAM • SSD 480GB

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC} ${BOLD}DIAGNÓSTICO HIGHLANDER v3.0${NC}                                  ${BLUE}║${NC}"
echo -e "${BLUE}║${NC} Lenovo 310-15ISK • i5-6200U • HD 520 • 8GB RAM • SSD 480GB    ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 1. INFORMAÇÕES DO SISTEMA
# ============================================
echo -e "${CYAN}▶ SISTEMA OPERACIONAL${NC}"
echo "  Distro: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
echo "  Arquitetura: $(uname -m)"
echo "  Uptime: $(uptime -p 2>/dev/null || uptime | awk -F',' '{print $1}')"
echo ""

# ============================================
# 2. CPU - i5-6200U (Skylake)
# ============================================
echo -e "${CYAN}▶ PROCESSADOR${NC}"
cpu_model=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
echo "  Modelo: $cpu_model"
echo "  Cores: $(nproc)"
echo "  Frequência: $(cat /proc/cpuinfo | grep MHz | head -1 | awk '{print $4}') MHz"

# Verificar TDP/turbo
echo -e "\n  ${YELLOW}• Configurações de Performance:${NC}"
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
    if [ "$turbo" == "0" ]; then
        echo -e "    Turbo: ${GREEN}✓ Ativado${NC}"
    else
        echo -e "    Turbo: ${RED}✗ Desativado${NC}"
    fi
fi

if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    if [ "$governor" == "performance" ]; then
        echo -e "    Governor: ${GREEN}✓ performance${NC}"
    else
        echo -e "    Governor: ${YELLOW}⚠ $governor${NC} (recomendado: performance)"
    fi
fi

# Temperatura
if command -v sensors &> /dev/null; then
    echo -e "\n  ${YELLOW}• Temperaturas:${NC}"
    sensors 2>/dev/null | grep -E "Core|Package|temp" | head -4
fi
echo ""

# ============================================
# 3. MEMÓRIA RAM + SWAP + ZRAM
# ============================================
echo -e "${CYAN}▶ MEMÓRIA${NC}"
echo -e "  ${YELLOW}• RAM Física:${NC}"
free -h | grep -E "Mem:|Swap:"

echo -e "\n  ${YELLOW}• ZRAM:${NC}"
if [ -f /sys/block/zram0/comp_algorithm ]; then
    zram_algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
    zram_size=$(lsblk -b -o NAME,SIZE | grep zram0 | awk '{print $2}')
    zram_size_gb=$(echo "scale=2; $zram_size/1024/1024/1024" | bc)
    echo -e "    Algoritmo: ${GREEN}$zram_algo${NC}"
    echo -e "    Tamanho: ${GREEN}${zram_size_gb}GB${NC}"
else
    echo -e "    ${RED}✗ ZRAM não encontrado${NC}"
fi

echo -e "\n  ${YELLOW}• Swap Files:${NC}"
swapon --show=NAME,SIZE,USED,PRIO | grep -E "swapfile|/swap" || echo "  Nenhum swapfile encontrado"

echo -e "\n  ${YELLOW}• Swappiness:${NC}"
current_swappiness=$(cat /proc/sys/vm/swappiness)
if [ "$current_swappiness" == "150" ]; then
    echo -e "    Valor: ${GREEN}$current_swappiness ✓ (otimizado)${NC}"
else
    echo -e "    Valor: ${YELLOW}$current_swappiness${NC} (esperado: 150)"
fi

echo -e "\n  ${YELLOW}• Overcommit Memory:${NC}"
echo "    Mode: $(cat /proc/sys/vm/overcommit_memory) (2=controlado)"
echo "    Ratio: $(cat /proc/sys/vm/overcommit_ratio)%"
echo ""

# ============================================
# 4. GPU - Intel HD 520 vs NVIDIA 920MX
# ============================================
echo -e "${CYAN}▶ PLACAS DE VÍDEO${NC}"

echo -e "  ${YELLOW}• Intel HD 520:${NC}"
if lsmod | grep -q i915; then
    echo -e "    Driver i915: ${GREEN}✓ Carregado${NC}"
else
    echo -e "    Driver i915: ${RED}✗ Não carregado${NC}"
fi

if grep -q "i915.enable_guc=3" /proc/cmdline; then
    echo -e "    enable_guc=3: ${GREEN}✓ Ativo no kernel${NC}"
else
    echo -e "    enable_guc=3: ${RED}✗ Não encontrado${NC}"
fi

# VA-API
if command -v vainfo &> /dev/null; then
    export LIBVA_DRIVER_NAME=iHD
    if vainfo 2>&1 | grep -q "VAEntrypointEncSlice"; then
        echo -e "    VA-API Encode: ${GREEN}✓ Disponível (h264_vaapi)${NC}"
    else
        echo -e "    VA-API Encode: ${YELLOW}⚠ Não disponível${NC}"
    fi
fi

echo -e "\n  ${YELLOW}• NVIDIA 920MX:${NC}"
if lsmod | grep -qE "nvidia|nouveau"; then
    echo -e "    Status: ${RED}✗ DRIVER CARREGADO (deveria estar desabilitado)${NC}"
else
    echo -e "    Status: ${GREEN}✓ Desabilitada (correto)${NC}"
fi
echo ""

# ============================================
# 5. DISCO - BTRFS
# ============================================
echo -e "${CYAN}▶ ARMAZENAMENTO${NC}"
root_fs=$(df -T / | tail -1 | awk '{print $2}')
echo "  Filesystem: $root_fs"

echo -e "\n  ${YELLOW}• Subvolumes BTRFS:${NC}"
btrfs subvolume list / 2>/dev/null | head -5 || echo "    Não disponível"

echo -e "\n  ${YELLOW}• TRIM:${NC}"
systemctl is-active fstrim.timer 2>/dev/null && echo -e "    ${GREEN}✓ Ativo${NC}" || echo -e "    ${YELLOW}⚠ Inativo${NC}"
echo ""

# ============================================
# 6. DOCKER
# ============================================
echo -e "${CYAN}▶ DOCKER${NC}"
if command -v docker &> /dev/null; then
    systemctl is-active docker &>/dev/null && echo -e "  Status: ${GREEN}✓ Ativo${NC}" || echo -e "  Status: ${YELLOW}⚠ Inativo${NC}"
    docker info 2>/dev/null | grep "Storage Driver"
else
    echo -e "  ${YELLOW}⚠ Docker não instalado${NC}"
fi
echo ""

# ============================================
# 7. POSTGRESQL
# ============================================
echo -e "${CYAN}▶ POSTGRESQL${NC}"
if command -v psql &> /dev/null; then
    psql --version | head -1
    systemctl is-active postgresql &>/dev/null && echo -e "  Status: ${GREEN}✓ Ativo${NC}" || echo -e "  Status: ${YELLOW}⚠ Inativo${NC}"
else
    echo -e "  ${YELLOW}⚠ PostgreSQL não instalado${NC}"
fi
echo ""

# ============================================
# 8. CLIPFUSION V.2
# ============================================
echo -e "${CYAN}▶ CLIPFUSION V.2${NC}"
CLIP_DIR="$HOME/ClipFusion_V.2"

if [ -d "$CLIP_DIR" ]; then
    echo -e "  Diretório: ${GREEN}✓ Encontrado${NC}"
    [ -d "$CLIP_DIR/venv" ] && echo -e "  VirtualEnv: ${GREEN}✓ Criado${NC}" || echo -e "  VirtualEnv: ${RED}✗ Não encontrado${NC}"
    
    # Testar faster-whisper
    if [ -f "$CLIP_DIR/venv/bin/python" ]; then
        test_result=$($CLIP_DIR/venv/bin/python -c "from faster_whisper import WhisperModel; print('OK')" 2>&1)
        [ "$test_result" == "OK" ] && echo -e "  faster-whisper: ${GREEN}✓ OK${NC}" || echo -e "  faster-whisper: ${RED}✗ Erro${NC}"
    fi
else
    echo -e "  ${RED}✗ Não encontrado${NC}"
fi
echo ""

# ============================================
# 9. CHECKLIST FINAL
# ============================================
echo -e "${CYAN}▶ CHECKLIST (13 otimizações)${NC}"

pass=0
total=13

# Testes rápidos
grep -q 'i915.enable_guc=3' /proc/cmdline && { echo -e "  ${GREEN}✓${NC} enable_guc=3"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} enable_guc=3"
[ -f /sys/block/zram0/comp_algorithm ] && { echo -e "  ${GREEN}✓${NC} ZRAM ativo"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} ZRAM"
[ "$(cat /proc/sys/vm/swappiness)" == "150" ] && { echo -e "  ${GREEN}✓${NC} Swappiness 150"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} Swappiness"
! lsmod | grep -qE "nvidia|nouveau" && { echo -e "  ${GREEN}✓${NC} NVIDIA bloqueada"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} NVIDIA ativa"
lsmod | grep -q i915 && { echo -e "  ${GREEN}✓${NC} i915 carregado"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} i915"
df -T / | grep -q btrfs && { echo -e "  ${GREEN}✓${NC} BTRFS"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} BTRFS"
command -v docker &>/dev/null && { echo -e "  ${GREEN}✓${NC} Docker"; pass=$((pass+1)); } || echo -e "  ${YELLOW}⚠${NC} Docker"
command -v psql &>/dev/null && { echo -e "  ${GREEN}✓${NC} PostgreSQL"; pass=$((pass+1)); } || echo -e "  ${YELLOW}⚠${NC} PostgreSQL"
[ -d "$HOME/ClipFusion_V.2" ] && { echo -e "  ${GREEN}✓${NC} ClipFusion"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} ClipFusion"
systemctl is-active thermald &>/dev/null && { echo -e "  ${GREEN}✓${NC} thermald"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} thermald"
systemctl is-active fstrim.timer &>/dev/null && { echo -e "  ${GREEN}✓${NC} fstrim.timer"; pass=$((pass+1)); } || echo -e "  ${RED}✗${NC} fstrim.timer"
[ "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)" == "performance" ] && { echo -e "  ${GREEN}✓${NC} Performance governor"; pass=$((pass+1)); } || echo -e "  ${YELLOW}⚠${NC} Governor"

echo ""
echo -e "${BOLD}Resultado: $pass/$total otimizações ativas${NC}"

if [ "$pass" -eq "$total" ]; then
    echo -e "${GREEN}🎉 Sistema totalmente otimizado!${NC}"
elif [ "$pass" -ge "$((total-2))" ]; then
    echo -e "${YELLOW}⚠️  Sistema quase otimizado${NC}"
else
    echo -e "${RED}❌ Várias otimizações pendentes${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo "Diagnóstico concluído em: $(date '+%Y-%m-%d %H:%M:%S')"
