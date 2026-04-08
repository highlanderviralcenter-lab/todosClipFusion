#!/usr/bin/env bash
set -euo pipefail

# Opens a GitHub compare URL in the browser (xdg-open) to start a PR quickly.
# Usage:
#   scripts/open_pr_compare.sh [base_branch] [compare_branch]
# Example:
#   scripts/open_pr_compare.sh main fix/clipfusion-final-clean

BASE_BRANCH="${1:-main}"
COMPARE_BRANCH="${2:-$(git branch --show-current)}"

if [[ -z "$COMPARE_BRANCH" ]]; then
  echo "[ERRO] Não foi possível detectar a branch atual." >&2
  exit 1
fi

REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
if [[ -z "$REMOTE_URL" ]]; then
  echo "[ERRO] Remote 'origin' não encontrado." >&2
  exit 1
fi

# Normalize ssh/https remote URLs to owner/repo
if [[ "$REMOTE_URL" =~ ^git@github.com:(.+)/(.+)\.git$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
elif [[ "$REMOTE_URL" =~ ^https://github.com/(.+)/(.+)(\.git)?$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  REPO="${REPO%.git}"
else
  echo "[ERRO] Remote não parece ser GitHub: $REMOTE_URL" >&2
  exit 1
fi

COMPARE_URL="https://github.com/${OWNER}/${REPO}/compare/${BASE_BRANCH}...${COMPARE_BRANCH}?expand=1"

echo "URL do PR compare:"
echo "$COMPARE_URL"

if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$COMPARE_URL" >/dev/null 2>&1 &
  echo "[OK] Link aberto com xdg-open."
else
  echo "[INFO] xdg-open não encontrado; abra a URL manualmente."
fi
