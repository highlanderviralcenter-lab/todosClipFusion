#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/HighcenterClipFusion"

if [[ ! -d "$APP_DIR" ]]; then
  echo "[run] ERRO: pasta HighcenterClipFusion não encontrada em $ROOT_DIR"
  exit 1
fi

chmod +x "$APP_DIR/run.sh"
exec "$APP_DIR/run.sh" "$@"
