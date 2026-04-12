# ✂ ClipFusion Viral Pro

**ClipFusion Viral Pro** é uma ferramenta completa para criar cortes virais de vídeos longos, otimizada para hardware i5-6200U + Intel HD 520.

## 🚀 Funcionalidades

- **Transcrição Whisper**: Python API (mais rápido, menos RAM que CLI)
- **Análise com IA**: Gera prompts para Claude/ChatGPT identificar cortes virais
- **Render 2-pass**: VA-API para corte + libx264 para legendas (não conflitam)
- **Anti-Copyright**: 7 módulos de proteção (4 níveis: none, basic, anti_ai, maximum)
- **Viral Engine**: 10 arquétipos emocionais, hook engine, audience analyzer, viral analyzer
- **GUI 7 abas**: Projeto | Transcrição | IA Externa | Cortes | Render | Histórico | Agenda
- **Lazy loading**: Módulos pesados só carregam quando necessários (~300MB economia)

## 📁 Estrutura

```
~/clipfusion/
├── main.py                    # Entry point
├── run.sh                     # Script de execução
├── install.sh                 # Script de instalação
├── config.yaml                # Configurações
├── requirements.txt           # Dependências Python
├── db.py                      # SQLite (histórico)
├── LEGACY.md                  # Arquivos legados descartados
├── utils/
│   ├── __init__.py
│   └── hardware.py            # HardwareDetector
├── core/
│   ├── __init__.py
│   ├── transcriber.py         # Whisper Python API
│   ├── cut_engine.py          # Render 2-pass
│   └── prompt_builder.py      # Prompt para IA externa
├── anti_copy_modules/         # 7 módulos anti-copyright
│   ├── __init__.py
│   ├── core.py                # AntiCopyrightEngine
│   ├── ai_evasion.py          # Perturba embeddings CNN
│   ├── audio_advanced.py      # Pitch ±0.05st + time stretch
│   ├── fingerprint_evasion.py # Cor, noise, chroma, frequency
│   ├── geometric_transforms.py # Zoom 1-3%, rotação
│   ├── temporal_obfuscation.py # Speed variation ±0.5%
│   └── network_evasion.py     # Agenda de upload
├── viral_engine/              # Motor viral completo
│   ├── __init__.py
│   ├── archetypes.py          # 10 arquétipos emocionais
│   ├── hook_engine.py         # Gerador de ganchos
│   ├── audience_analyzer.py   # Perfis demográficos
│   ├── platform_optimizer.py  # TikTok/Reels/Shorts
│   ├── secondary_group.py     # Dual hook strategy
│   └── viral_analyzer.py      # Motor de análise viral auto-contido
├── gui/
│   ├── __init__.py
│   └── main_gui.py            # Interface Tkinter (7 abas)
├── config/
│   ├── perfis_nicho.json      # Perfis customizados por nicho
│   └── profiles/              # Perfis de configuração
└── output/
    ├── prompts/               # Prompts gerados
    ├── scripts/               # Scripts de upload
    └── reports/               # Relatórios de análise
```

## ⚡ Instalação

```bash
# 1. Clone ou copie o projeto
cd ~/clipfusion

# 2. Execute o script de instalação
chmod +x install.sh
./install.sh

# 3. Inicie a aplicação
./run.sh
```

## 🔧 Requisitos

- Debian/Ubuntu com kernel otimizado (i915.enable_guc=3)
- Python 3.8+
- FFmpeg
- Intel HD 520 (VA-API recomendado)
- 8GB RAM (com gc.collect() explícito entre cortes)

## 🎮 Uso

1. **Aba Projeto**: Selecione o vídeo e configure opções
2. **Aba Transcrição**: Revise a transcrição Whisper
3. **Aba IA Externa**: Copie o prompt, cole no Claude/ChatGPT, traga o JSON
4. **Aba Cortes**: Selecione os cortes aprovados
5. **Aba Render**: Acompanhe o progresso
6. **Aba Histórico**: Gerencie projetos anteriores
7. **Aba Agenda**: Gere horários de upload anti-padrão

## 🛡️ Níveis Anti-Copyright

| Nível | Descrição |
|-------|-----------|
| 🟢 NENHUM | Arquivo original intacto |
| 🟡 BÁSICO | Zoom, cor, metadados, áudio básico |
| 🟠 ANTI-IA | + noise, chroma, anti-detecção IA |
| 🔴 MÁXIMO | Todas as técnicas avançadas |

## 🧠 Motor de Análise Viral

O `viral_analyzer.py` é um motor auto-contido que analisa conteúdo para viralização:

```python
from viral_engine.viral_analyzer import ViralEngine

engine = ViralEngine()

# Detectar nicho automaticamente
nicho = engine.detect_nicho(transcricao)

# Analisar audiência
audience = engine.analyze_audience(transcricao)

# Score de viralidade para um corte
resultado = engine.score_cut(texto_corte, duracao)
# Retorna: viral_score, retenção, shareability, comentabilidade, etc.

# Rankear múltiplos cortes
ranking = engine.rank_cuts(lista_cortes)
```

### Funcionalidades do Motor Viral

- **Detecção automática de nicho**: investimentos, fitness, tecnologia, relacionamentos, empreendedorismo
- **Análise de audiência**: demografia, psicografia, comportamento, horários ótimos
- **Detecção de arquétipo emocional**: 10 padrões emocionais
- **Geração de hooks**: 3 variações otimizadas por corte
- **Scoring completo**: retenção, shareability, comentabilidade, watch time
- **Sugestão de plataforma**: TikTok, Reels ou Shorts
- **Recomendações de melhoria**: ações específicas para aumentar viralidade

## 📄 Legado

Veja `LEGACY.md` para arquivos antigos descartados e notas de migração.

## 📄 Licença

Projeto para uso pessoal e educacional.
