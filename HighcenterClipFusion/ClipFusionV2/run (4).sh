#!/bin/bash
cd "$(dirname "$0")"
export LIBVA_DRIVER_NAME=i965
export MESA_LOADER_DRIVER_OVERRIDE=i965
export LIBVA_DRI3_DISABLE=1
export OMP_NUM_THREADS=2
source venv/bin/activate 2>/dev/null || true
python3 main.sh "$@"
