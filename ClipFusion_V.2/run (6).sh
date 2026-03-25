#!/bin/bash
cd "$(dirname "$0")"
export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
source venv/bin/activate
echo "🔍 Verificando sistema..."
cd src && python3 -c "from utils.hardware import check_system; check_system()" 2>/dev/null || true && cd ..
echo ""
echo "🚀 Iniciando ClipFusion Viral Pro..."
python3 src/main.py
