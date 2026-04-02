#!/usr/bin/env bash
set -euo pipefail
echo "Kernel cmdline:"; cat /proc/cmdline
echo "VAAPI:"; command -v vainfo >/dev/null && vainfo | head -n 5 || echo "vainfo não instalado"
echo "Swaps:"; swapon --show || true
echo "Swappiness:"; sysctl -n vm.swappiness || true
