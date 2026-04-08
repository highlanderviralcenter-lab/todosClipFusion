# ClipFusion V3 (pacote limpo)

Esta pasta contém **somente os arquivos canônicos** da versão V3, sem cópias históricas.

## Estrutura
- `app_V3/` código da aplicação
- `scripts_V3/` instaladores, diagnósticos e utilitários
- `docs_V3/` documentação consolidada
- `start_V3.sh` inicialização única da V3

## Execução em 1 comando (recomendado)
Da pasta `ClipFusion_V.3/`, rode:

```bash
bash start_V3.sh
```

Isso faz:
1. diagnóstico rápido do host,
2. cria `.venv` em `app_V3/` se não existir,
3. instala dependências Python,
4. inicia a GUI (`run_V3.sh`).

### Primeira instalação no notebook (com tuning de sistema)
```bash
bash start_V3.sh --with-system-install
```

> O instalador de sistema usa `sudo` e configura Debian (drivers, zRAM/swap, sysctl, i915.enable_guc=3).

## Passo a passo manual (alternativo)
```bash
cd app_V3
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements_V3.txt
bash run_V3.sh
```

## Fluxo Git/PR sem erro de merge
Sempre sincronize antes de abrir PR:

```bash
cd ~/todosClipFusion
git checkout main
git pull origin main
```

Depois abra compare/PR automaticamente (com navegador):

```bash
cd ~/todosClipFusion/ClipFusion_V.3
bash scripts_V3/open_pr_compare_V3.sh main <sua-branch>
```

Se omitir `<sua-branch>`, o script usa a branch atual.

## Observação importante
Arquivos principais com sufixo `_V3`:
- `main_V3.py`
- `db_V3.py`
- `requirements_V3.txt`
- `run_V3.sh`
- scripts em `scripts_V3/*_V3.sh`
- `manual_tecnico_V3.md`
