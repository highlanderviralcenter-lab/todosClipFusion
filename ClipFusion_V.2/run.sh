#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

if [ ! -d venv ]; then
  echo "venv não encontrado. Rode ./instalar_clipfusion_v2_completo.sh primeiro."
  exit 1
fi

source venv/bin/activate

echo "Iniciando ClipFusion Viral Pro..."

if [ -f src/gui/main_gui.py ]; then
  python src/gui/main_gui.py
elif [ -f main.py ]; then
  python main.py
else
  echo "Nenhum entrypoint encontrado."
  exit 1
fi
