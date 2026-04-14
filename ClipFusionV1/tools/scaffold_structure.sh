#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-ClipFusionV1}"
mkdir -p "$ROOT"/{app,core/contracts,anti_copy_modules,viral_engine,gui/viewmodels,infra,installers,config/profiles,run,tests/smoke,tests/regression,tests/fixtures,output/{prompts,reports,renders,logs},docs,requirements,tools}
echo "Estrutura criada em $ROOT"
