# 🗂️ Arquivos Legados - ClipFusion Viral Pro

Este documento registra componentes antigos que foram descartados ou substituídos em versões anteriores.

---

## ❌ Descartados

### Bootstrap Placeholder (Versão Antiga)
- **Arquivo**: `bootstrap.py` (placeholder)
- **Status**: ❌ DESCARTADO
- **Motivo**: Substituído por estrutura modular completa com `main.py` como entry point
- **Data descarte**: 2024

### AntiCopyAdvanced Monolítico
- **Arquivo**: `anti_copy_advanced.py` (monolítico)
- **Status**: ❌ DESCARTADO
- **Motivo**: Refatorado em 7 módulos separados em `anti_copy_modules/`
  - `core.py` - Engine principal
  - `ai_evasion.py` - Perturbação de embeddings CNN
  - `audio_advanced.py` - Pitch/time stretch
  - `fingerprint_evasion.py` - Cor/noise/chroma/frequency
  - `geometric_transforms.py` - Zoom/rotação/perspectiva
  - `temporal_obfuscation.py` - Speed variation
  - `network_evasion.py` - Agenda de upload
- **Data descarte**: 2024

### Motor de Análise Viral (Versão Antiga)
- **Arquivo**: `motordeanaliseviral.txt`
- **Status**: ❌ DESCARTADO / INTEGRADO
- **Motivo**: Funcionalidades integradas em `viral_engine/viral_analyzer.py`
- **Data integração**: 2024

---

## ✅ Estrutura Atual (Vigente)

```
clipfusion/
├── main.py                    # Entry point atual
├── db.py                      # SQLite persistente
├── config.yaml                # Configurações centralizadas
├── requirements.txt           # Dependências
├── install.sh                 # Script de instalação
├── run.sh                     # Script de execução
├── utils/
│   └── hardware.py            # HardwareDetector
├── core/
│   ├── transcriber.py         # Whisper Python API
│   ├── cut_engine.py          # Render 2-pass
│   └── prompt_builder.py      # Prompt IA externa
├── anti_copy_modules/         # 7 módulos modulares
├── viral_engine/              # Motor viral completo
│   ├── archetypes.py          # 10 arquétipos
│   ├── hook_engine.py         # Gerador de hooks
│   ├── audience_analyzer.py   # Perfis demográficos
│   ├── platform_optimizer.py  # Specs por plataforma
│   ├── secondary_group.py     # Estratégia dual hook
│   └── viral_analyzer.py      # Motor de análise viral
├── gui/
│   └── main_gui.py            # Interface 7 abas
├── config/
│   ├── perfis_nicho.json      # Perfis customizados por nicho
│   └── profiles/              # Perfis de configuração
└── output/
    ├── prompts/               # Prompts gerados
    ├── scripts/               # Scripts de upload
    └── reports/               # Relatórios de análise
```

---

## 🔄 Compatibilidade Config

### Config Novo (`config.yaml`)
```yaml
hardware:
  encoder_preferido: "auto"
  max_ram_gb: 6
  usar_gpu_intel: true

whisper:
  modelo: "tiny"
  idioma: "pt"
  dispositivo: "cpu"

render:
  preset: "fast"
  crf: 23
  usar_vaapi: true

anti_copy:
  nivel: "basic"
```

### Config Antigo (LEGADO)
- Arquivos `.ini` ou `.json` espalhados
- **Status**: Não suportado
- **Migração**: Converter manualmente para `config.yaml`

---

## 📝 Notas de Migração

Se você tinha versões anteriores:

1. **Backup** seus projetos em `~/.clipfusion/`
2. **Reinstale** usando `install.sh`
3. **Migre** configurações antigas para `config.yaml`
4. **Delete** arquivos legados listados acima

---

*Última atualização: 2024*
