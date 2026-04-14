# SYSTEM_MAP - ClipFusionV1

Data baseline: 2026-04-14

## Fonte oficial
A partir desta fase, os arquivos em `ClipFusionV1/` são a base canônica.

## Mapa de módulos
- `app/`: orquestração e fila.
- `core/`: ingestão, transcrição, segmentação, decisão e render.
- `anti_copy_modules/`: camadas de proteção.
- `viral_engine/`: estratégia editorial e arquétipos.
- `infra/`: banco, logs e utilidades de plataforma.
- `gui/`: interface local Tkinter.
- `run/`: execução e preflight.
- `installers/`: instalação Debian e rollback.
- `tests/`: smoke/regressão.

## Tabela de baseline
| Arquivo final | Fonte original | Justificativa |
|---|---|---|
| run/run.sh | run/run.sh | baseline canônica desta nova fase |
| app/main.py | app/main.py | entrypoint CLI canônico |
| gui/main_gui.py | gui/main_gui.py | interface principal |
