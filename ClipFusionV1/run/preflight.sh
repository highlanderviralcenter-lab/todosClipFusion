#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[ClipFusionV1] preflight start"
command -v python3 >/dev/null || { echo "python3 não encontrado"; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg não encontrado"; exit 1; }

FREE_MB=$(df -Pm "$ROOT_DIR" | awk 'NR==2 {print $4}')
if [ "${FREE_MB:-0}" -lt 2048 ]; then
  echo "Pouco espaço em disco (<2GB)"; exit 1
fi

python3 - <<'PY'
import importlib.util
mods = ["tkinter", "sqlite3"]
for m in mods:
    if importlib.util.find_spec(m) is None:
        raise SystemExit(f"Modulo ausente: {m}")
print("python modules ok")
PY

echo "[ClipFusionV1] preflight ok"
