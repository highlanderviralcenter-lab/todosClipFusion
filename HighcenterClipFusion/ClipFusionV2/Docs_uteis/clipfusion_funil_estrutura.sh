#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-$HOME/clipfusion}"

mkdir -p \
  "$BASE/_entrada/viral_engine" \
  "$BASE/_entrada/gui" \
  "$BASE/_entrada/anti_copy_modules" \
  "$BASE/_entrada/scheduler" \
  "$BASE/_entrada/utils" \
  "$BASE/_entrada/notas" \
  "$BASE/config" \
  "$BASE/utils" \
  "$BASE/core" \
  "$BASE/gui" \
  "$BASE/viral_engine" \
  "$BASE/scheduler" \
  "$BASE/anti_copy_modules"

for f in \
  "$BASE/utils/__init__.py" \
  "$BASE/core/__init__.py" \
  "$BASE/gui/__init__.py" \
  "$BASE/viral_engine/__init__.py" \
  "$BASE/scheduler/__init__.py" \
  "$BASE/anti_copy_modules/__init__.py"
  do
  [ -f "$f" ] || : > "$f"
done

cat > "$BASE/README_MAPA.md" <<'MAPEOF'
Veja o arquivo clipfusion_mapa_final.md para a estratégia de montagem.
Fluxo recomendado:
1. base do app já existente
2. jogar complementos em _entrada/
3. renomear e mover por módulo
4. só integrar no app final depois
MAPEOF

printf 'Estrutura criada em: %s\n' "$BASE"
printf '\nPastas de entrada:\n'
find "$BASE/_entrada" -maxdepth 2 -type d | sort
