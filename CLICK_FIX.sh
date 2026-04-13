#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "[CLICK_FIX] Iniciando correção automática..."

TARGETS=(
  "HighcenterClipFusion/main_gui.py"
  "HighcenterClipFusion/cut_engine.py"
  "HighcenterClipFusion/requirements.txt"
  "HighcenterClipFusion/run.sh"
)

BACKUP_DIR="$ROOT_DIR/.fix_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
for f in "${TARGETS[@]}"; do
  if [[ -f "$f" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp "$f" "$BACKUP_DIR/$f"
  fi
done

echo "[CLICK_FIX] Backup salvo em: $BACKUP_DIR"

# 1) Resolve conflitos recorrentes (se houver)
if [[ -x "$ROOT_DIR/scripts/resolve_conflicts.sh" ]]; then
  "$ROOT_DIR/scripts/resolve_conflicts.sh" || true
fi

# 2) Corrige bug comum: keyword repetida subtitle_text
if [[ -f "HighcenterClipFusion/main_gui.py" ]]; then
  sed -i '/subtitle_text=c\["text"\],/d' HighcenterClipFusion/main_gui.py
fi

# 3) Garante dependências mínimas
if [[ -f "HighcenterClipFusion/requirements.txt" ]]; then
  grep -q '^gTTS==2.5.4$' HighcenterClipFusion/requirements.txt || echo 'gTTS==2.5.4' >> HighcenterClipFusion/requirements.txt
  grep -q '^deep-translator==1.11.4$' HighcenterClipFusion/requirements.txt || echo 'deep-translator==1.11.4' >> HighcenterClipFusion/requirements.txt
fi

# 4) Verifica conflitos residuais
if command -v rg >/dev/null 2>&1; then
  if rg -n '^<<<<<<<|^>>>>>>>' HighcenterClipFusion scripts >/tmp/click_fix_conflicts.log 2>/dev/null; then
    echo "[CLICK_FIX] Ainda há conflitos após tentativa automática:"
    cat /tmp/click_fix_conflicts.log
    exit 2
  fi
fi

# 5) Smoke checks
cd "$ROOT_DIR/HighcenterClipFusion"
python3 -m py_compile *.py

echo "[CLICK_FIX] OK. Correções aplicadas e sintaxe validada."
echo "[CLICK_FIX] Para executar com 1 clique/comando: $ROOT_DIR/run.sh"
