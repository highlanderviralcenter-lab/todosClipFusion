#!/bin/bash
# ==============================================================================
# Diagnóstico Completo do ClipFusion + Sistema
# Autor: Highlander (com assistência)
# Data: $(date +%Y-%m-%d)
# ==============================================================================

set -e

OUTPUT_FILE="/tmp/diagnostico_clipfusion_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$OUTPUT_FILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DIAGNÓSTICO COMPLETO - CLIPFUSION + SISTEMA           ║${NC}"
echo -e "${BLUE}║     Hardware: i5-6200U + Intel HD 520                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo "Data: $(date)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. INFORMAÇÕES BÁSICAS DO SISTEMA
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 1. SISTEMA OPERACIONAL${NC}"
echo "Kernel: $(uname -r)"
echo "Distro: $(lsb_release -d | cut -f2)"
echo "Uptime: $(uptime -p)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 2. HARDWARE DETECTADO
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 2. HARDWARE${NC}"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "Cores: $(nproc)"
echo "RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo "GPU:"
lspci | grep -E "VGA|3D|Display" | sed 's/^/  /'
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 3. KERNEL PARAMETERS (DEBIAN TUNADO)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 3. PARÂMETROS DO KERNEL${NC}"
cat /proc/cmdline | fold -s
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 4. MÓDULOS CARREGADOS (NVIDIA BLOQUEADA?)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 4. MÓDULOS NVIDIA/NOUVEAU${NC}"
lsmod | grep -E "nvidia|nouveau" || echo "Nenhum módulo NVIDIA/nouveau carregado (✅)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 5. VA-API / DRIVERS INTEL
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 5. VA-API (ACELERAÇÃO DE VÍDEO)${NC}"
if command -v vainfo &>/dev/null; then
    vainfo 2>&1 | grep -E "Driver version|VAProfileH264.*EncSlice" || echo "❌ H.264 encode não disponível"
else
    echo "vainfo não instalado"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 6. VARIÁVEIS DE AMBIENTE
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 6. VARIÁVEIS DE AMBIENTE (VA-API)${NC}"
echo "LIBVA_DRIVER_NAME = $LIBVA_DRIVER_NAME"
echo "LIBVA_DRIVERS_PATH = $LIBVA_DRIVERS_PATH"
echo "MESA_LOADER_DRIVER_OVERRIDE = $MESA_LOADER_DRIVER_OVERRIDE"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 7. FIRMWARE i915 (Skylake)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 7. FIRMWARE i915 SKYLAKE${NC}"
ls -lh /lib/firmware/i915/skl_* 2>/dev/null || echo "❌ Firmware não encontrado"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 8. TESTE DE ENCODE VA-API COM FFMPEG
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 8. TESTE DE ENCODE H.264 VIA VA-API${NC}"
if command -v ffmpeg &>/dev/null; then
    TMP_VIDEO="/tmp/test_vaapi_$$.mp4"
    echo "Gerando vídeo de teste com aceleração VA-API..."
    ffmpeg -hide_banner -y \
        -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \
        -f lavfi -i testsrc=duration=5:size=1280x720:rate=30 \
        -vf "scale_vaapi=1280:720" -c:v h264_vaapi -b:v 2M \
        "$TMP_VIDEO" 2>&1 | grep -E "fps|speed|frame"
    if [ -f "$TMP_VIDEO" ]; then
        echo "✅ Vídeo gerado com sucesso: $TMP_VIDEO"
        rm -f "$TMP_VIDEO"
    else
        echo "❌ Falha na geração do vídeo"
    fi
else
    echo "ffmpeg não instalado"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 9. TESTE DE REPRODUÇÃO COM ACELERAÇÃO (MPV)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 9. TESTE DE REPRODUÇÃO COM ACELERAÇÃO${NC}"
if command -v mpv &>/dev/null; then
    echo "Teste interativo: execute manualmente:"
    echo "  mpv --hwdec=vaapi --vo=gpu /caminho/do/video.mp4"
    echo "Enquanto isso, em outro terminal: sudo intel_gpu_top"
else
    echo "mpv não instalado (opcional)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 10. TESTE DE TRANSCRIÇÃO COM WHISPER (USANDO ÁUDIO DE EXEMPLO)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 10. TESTE DE TRANSCRIÇÃO WHISPER${NC}"
if command -v whisper &>/dev/null || python3 -c "import whisper" 2>/dev/null; then
    # Criar um áudio de exemplo (fala sintética)
    TMP_WAV="/tmp/test_speech_$$.wav"
    TMP_TXT="/tmp/test_speech_$$.txt"
    echo "Gerando áudio de exemplo com fala sintética..."
    espeak-ng "Este é um teste de transcrição do Whisper. Vamos ver se a qualidade está boa." -w "$TMP_WAV" 2>/dev/null || \
        ffmpeg -f lavfi -i "sine=frequency=1000:duration=3" -af "aecho=0.8:0.2:10:0.5" "$TMP_WAV" 2>/dev/null
    if [ -f "$TMP_WAV" ]; then
        whisper "$TMP_WAV" --model tiny --language pt --output_dir /tmp/ > "$TMP_TXT" 2>&1
        echo "Resultado da transcrição:"
        cat /tmp/test_speech_*.txt | head -20
        rm -f "$TMP_WAV" /tmp/test_speech_*
    else
        echo "❌ Falha ao gerar áudio de exemplo"
    fi
else
    echo "whisper não instalado"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 11. TESTE DE RENDER DE UM CORTE SIMPLES (USANDO O PRÓPRIO CLIPFUSION)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 11. TESTE DE RENDER (CORTE SIMULADO)${NC}"
if [ -d ~/clipfusion ]; then
    cd ~/clipfusion
    source venv/bin/activate 2>/dev/null || true
    python3 -c "
import sys
sys.path.insert(0, '.')
from core.cut_engine import render_cut, _detect_vaapi
from core.transcriber import fmt_time
import os, tempfile, shutil

# Criar vídeo de teste (1 segundo, preto)
test_video = '/tmp/test_cut.mp4'
os.system(f'ffmpeg -y -f lavfi -i color=c=black:s=1920x1080:d=5 -frames:v 1 {test_video} 2>/dev/null')

# Criar segmentos fictícios
segments = [{'start': 0.0, 'end': 5.0, 'text': 'Frase de exemplo para teste.'}]
cut = {'start': 0.5, 'end': 4.5, 'cut_index': 0, 'title': 'teste', 'platforms': ['tiktok']}
out_dir = tempfile.mkdtemp()

try:
    result = render_cut(test_video, cut, segments, out_dir, 'teste', ace_level='none', use_vaapi=True)
    if result:
        print('✅ Render do corte concluído')
        for p, path in result.items():
            print(f'  {p}: {os.path.basename(path)}')
    else:
        print('❌ Falha no render')
finally:
    shutil.rmtree(out_dir, ignore_errors=True)
    os.remove(test_video)
" 2>&1 | grep -E "✅|❌|Render"
else
    echo "ClipFusion não encontrado em ~/clipfusion"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 12. STATUS DA MEMÓRIA (ZRAM + SWAP)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 12. MEMÓRIA E SWAP${NC}"
swapon --show
echo "swappiness: $(sysctl -n vm.swappiness)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 13. TEMPERATURA DA CPU
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 13. TEMPERATURA${NC}"
if command -v sensors &>/dev/null; then
    sensors | grep -E "Core|Package" || echo "sensors não retornou dados"
else
    echo "lm-sensors não instalado"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 14. LOGS RECENTES DO KERNEL (i915, drm)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 14. ÚLTIMAS MENSAGENS DO KERNEL SOBRE i915/DRM${NC}"
dmesg | grep -E "i915|drm" | tail -20
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 15. VERIFICAÇÃO DO ARQUIVO DE CONFIGURAÇÃO DO CLIPFUSION
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 15. CONFIGURAÇÃO DO CLIPFUSION${NC}"
if [ -f ~/clipfusion/config.yaml ]; then
    grep -E "encoder_preferido|usar_vaapi|modelo" ~/clipfusion/config.yaml | sed 's/^/  /'
else
    echo "config.yaml não encontrado"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 16. TESTE DE VELOCIDADE DE ENCODE (FPS)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 16. TESTE DE VELOCIDADE DE ENCODE (FPS)${NC}"
if command -v ffmpeg &>/dev/null; then
    echo "Medindo fps com VA-API..."
    ffmpeg -hide_banner -y \
        -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \
        -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 \
        -vf "scale_vaapi=1280:720" -c:v h264_vaapi -b:v 2M \
        -f null - 2>&1 | grep "fps=" | tail -1
else
    echo "ffmpeg não instalado"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 17. RESUMO DAS VERIFICAÇÕES DO DEBIAN TUNADO (USANDO O validate-system.sh)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}▶ 17. VALIDAÇÃO DO DEBIAN TUNADO${NC}"
if [ -x /usr/local/bin/validate-system.sh ]; then
    /usr/local/bin/validate-system.sh | grep -E "PASS|FAIL|WARN|✅|❌" | tail -20
else
    echo "validate-system.sh não encontrado"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# FINALIZAÇÃO
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Diagnóstico concluído.${NC}"
echo "Arquivo salvo em: $OUTPUT_FILE"
echo "Cole o conteúdo desse arquivo na sua próxima mensagem para análise."
