#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./run/preflight.sh

python3 -m venv .venv
source .venv/bin/activate
pip install -U pip >/dev/null
pip install -r requirements/base.txt >/dev/null

if [ "${1:-}" = "--cli" ]; then
  shift
  python -m app.main "$@"
else
  python -m gui.main_gui
fi
