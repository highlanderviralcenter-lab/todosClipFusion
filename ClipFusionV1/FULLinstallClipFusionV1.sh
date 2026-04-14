#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "[ClipFusionV1] instalação iniciada"

if ! command -v python3 >/dev/null; then
  echo "python3 não encontrado"; exit 1
fi
if ! command -v ffmpeg >/dev/null; then
  echo "ffmpeg não encontrado. Instale via apt."; exit 1
fi

python3 -m venv .venv
source .venv/bin/activate
pip install -U pip >/dev/null
pip install -r requirements/base.txt >/dev/null

mkdir -p output/{prompts,reports,renders,logs,data}

./run/preflight.sh
python3 -m py_compile $(find . -name '*.py')

cat > output/reports/install_report.md <<'MD'
# Install report ClipFusionV1
status: OK
steps:
- venv criado
- dependências base instaladas
- preflight ok
- py_compile ok
MD

echo "[ClipFusionV1] instalação concluída"
echo "Execute: ./run/run.sh"
