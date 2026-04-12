#!/usr/bin/env bash
set -euo pipefail

# Resolve recurring GitHub merge conflicts by keeping the current branch's
# canonical HighcenterClipFusion implementation.

FILES=(
  "HighcenterClipFusion/cut_engine.py"
  "HighcenterClipFusion/main_gui.py"
  "HighcenterClipFusion/requirements.txt"
  "HighcenterClipFusion/run.sh"
)

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "[resolve_conflicts] Not inside a git repository."
  exit 1
fi

if ! git diff --name-only --diff-filter=U | grep -q .; then
  echo "[resolve_conflicts] No merge conflicts detected."
  exit 0
fi

for f in "${FILES[@]}"; do
  if git ls-files -u -- "$f" | grep -q .; then
    echo "[resolve_conflicts] keeping OURS for $f"
    git checkout --ours -- "$f"
    git add "$f"
  fi
done

if git diff --name-only --diff-filter=U | grep -q .; then
  echo "[resolve_conflicts] Some conflicts remain. Resolve manually:"
  git diff --name-only --diff-filter=U
  exit 2
fi

echo "[resolve_conflicts] Conflicts resolved for targeted files."
echo "Now run: git commit -m 'fix: resolve recurring HighcenterClipFusion merge conflicts'"
