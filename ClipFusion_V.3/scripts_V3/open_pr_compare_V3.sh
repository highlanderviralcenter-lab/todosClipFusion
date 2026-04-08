#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PR_SCRIPT="$ROOT_DIR/scripts/open_pr_compare.sh"

if [[ ! -x "$PR_SCRIPT" ]]; then
  echo "[ERRO] Script não encontrado: $PR_SCRIPT"
  echo "Dica: atualize o repositório com 'git pull origin main'."
  exit 1
fi

exec "$PR_SCRIPT" "$@"
