#!/usr/bin/env bash
set -e
source .venv/bin/activate
python src/render_pipeline.py --video "$1" --cuts "$2" --output "$3"
