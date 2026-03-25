#!/bin/bash
# ClipFusion Viral Pro — Script de execução otimizado para i5-6200U + Intel HD 520
# CORREÇÕES: Driver i965, variáveis anti-hang, prioridade de processo

cd "$(dirname "$0")"

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÃO CRÍTICA PARA INTEL HD 520 (Skylake) — EVITA GPU HANG
# ═══════════════════════════════════════════════════════════════════════════════

# FIX: Usa driver i965 (mais estável) em vez de iHD moderno que causa hangs [^25^]
export LIBVA_DRIVER_NAME=i965
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri

# FIX: Evita driver Iris que causa crashes na HD 520 [^25^]
export MESA_LOADER_DRIVER_OVERRIDE=i965

# FIX: Desabilita DRI3 que causa instabilidade em GPUs Intel antigas [^27^]
export LIBVA_DRI3_DISABLE=1

# FIX: Limita threads OpenMP para evitar sobrecarga
export OMP_NUM_THREADS=2
export OPENBLAS_NUM_THREADS=2
export MKL_NUM_THREADS=2

# FIX: Configurações de memória para 8GB RAM
export MALLOC_ARENA_MAX=2

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ClipFusion Viral Pro — Modo Skylake Stable (HD 520)          ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Driver VA-API: i965 (estável)                                ║"
echo "║  Threads: Limitado a 2 (evita overflow)                       ║"
echo "║  GPU Hang Protection: Ativo                                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Ativa ambiente Python
source venv/bin/activate

# Verifica sistema
echo "🔍 Verificando hardware..."
python3 -c "from utils.hardware import check_system; check_system()" 2>/dev/null || true
echo ""

# FIX: Aumenta prioridade do processo (evita starvation)
echo "🚀 Iniciando ClipFusion Viral Pro..."
echo "   Pressione Ctrl+C para sair"
echo ""

# Executa com nice ajustado (prioridade normal, não agressiva)
nice -n 0 python3 main.py

# Captura saída para log de debug se necessário
# python3 main.py 2>&1 | tee clipfusion_$(date +%Y%m%d_%H%M%S).log
