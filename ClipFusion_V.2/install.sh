#!/bin/bash
set -e
GRN='\033[0;32m'; YEL='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GRN}[✓]${NC} $1"; }
warn() { echo -e "${YEL}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "╔═════════════════════════════════════════╗"
echo "║  ClipFusion Viral Pro — Instalação     ║"
echo "║  Hardware: i5-6200U + Intel HD 520     ║"
echo "╚═════════════════════════════════════════╝"
echo ""

# 1. Verificação do Debian Tunado
if ! grep -q "i915.enable_guc=3" /proc/cmdline; then
    warn "Kernel sem i915.enable_guc=3 — execute o Debian Tunado 3.0 primeiro."
fi

# 2. Dependências do sistema
sudo apt update -qq
sudo apt install -y \
    python3 python3-pip python3-venv python3-tk \
    ffmpeg git curl wget \
    intel-media-va-driver-non-free \
    libva-drm2 libva-x11-2 libva-glx2 \
    i965-va-driver-shaders \
    vainfo intel-gpu-tools \
    lm-sensors 2>/dev/null || true
ok "Dependências do sistema (VA-API Intel HD 520 incluído)"

# 3. Validação VA-API
echo "Verificando VA-API..."
export LIBVA_DRIVER_NAME=iHD
if vainfo 2>&1 | grep -q "VAEntrypointEncSlice"; then
    ok "VA-API Intel HD 520 — H.264 encode disponível (3x mais rápido)"
elif vainfo 2>&1 | grep -q "i965"; then
    warn "VA-API driver i965 (fallback) — funciona, mas mais lento que iHD"
else
    warn "VA-API não detectado — render usará CPU (libx264)"
fi

# Persiste variáveis VA-API
if ! grep -q "LIBVA_DRIVER_NAME" ~/.bashrc 2>/dev/null; then
    echo 'export LIBVA_DRIVER_NAME=iHD' >> ~/.bashrc
    echo 'export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri' >> ~/.bashrc
fi

# 4. Estrutura de pastas
mkdir -p ~/clipfusion
cd ~/clipfusion
mkdir -p utils core gui anti_copy_modules viral_engine config
touch utils/__init__.py core/__init__.py gui/__init__.py
touch anti_copy_modules/__init__.py viral_engine/__init__.py
mkdir -p ~/.clipfusion  # banco SQLite
ok "Estrutura de pastas criada"

# 5. Ambiente Python
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip --quiet
pip install openai-whisper numpy pillow pyyaml --quiet
ok "Pacotes Python instalados"

# 6. Verifica instalação
python3 -c "import whisper" 2>/dev/null && ok "Whisper OK" || err "Whisper falhou"
command -v ffmpeg &>/dev/null && ok "FFmpeg: $(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')" || err "FFmpeg não encontrado"

# 7. Script de execução
cat > ~/clipfusion/run.sh << 'RUNEOF'
#!/bin/bash
cd "$(dirname "$0")"
export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
source venv/bin/activate
echo "🔍 Verificando sistema..."
python3 -c "from utils.hardware import check_system; check_system()" 2>/dev/null || true
echo ""
echo "🚀 Iniciando ClipFusion Viral Pro..."
python3 main.py
RUNEOF
chmod +x ~/clipfusion/run.sh
ok "run.sh criado"

echo ""
echo "╔═════════════════════════════════════════╗"
echo "║  ✅ PRONTO — para iniciar:             ║"
echo "║     cd ~/clipfusion && ./run.sh        ║"
echo "╚═════════════════════════════════════════╝"
echo ""
