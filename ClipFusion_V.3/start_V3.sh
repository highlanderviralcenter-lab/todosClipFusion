#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/app_V3"
SCRIPTS_DIR="$ROOT_DIR/scripts_V3"

WITH_SYSTEM_INSTALL=0
SKIP_PIP=0

for arg in "$@"; do
  case "$arg" in
    --with-system-install) WITH_SYSTEM_INSTALL=1 ;;
    --skip-pip) SKIP_PIP=1 ;;
    *)
      echo "Uso: bash start_V3.sh [--with-system-install] [--skip-pip]"
      exit 1
      ;;
  esac
done

if [[ "$WITH_SYSTEM_INSTALL" -eq 1 ]]; then
  echo "[V3] Executando instalador de sistema (sudo)..."
  bash "$SCRIPTS_DIR/install_debian_V3.sh"
fi

echo "[V3] Rodando diagnóstico rápido..."
bash "$SCRIPTS_DIR/diagnostic_V3.sh" || true

cd "$APP_DIR"

if [[ ! -d .venv ]]; then
  echo "[V3] Criando virtualenv em app_V3/.venv"
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

if [[ "$SKIP_PIP" -eq 0 ]]; then
  echo "[V3] Instalando dependências Python"
  python3 -m pip install -U pip
  python3 -m pip install -r requirements_V3.txt
fi

echo "[V3] Iniciando app..."
exec bash run_V3.sh
