#!/usr/bin/env python3
"""
Aplica o patch do ClipFusion com backup automático.

Uso:
  python3 apply_clipfusion_patch.py /caminho/para/ClipFusion-a-arte-viral-

Ele:
- valida se a pasta parece ser a raiz do repo
- cria backup em ./_backup_patch_<timestamp>/
- substitui:
    core/transcriber.py
    core/prompt_builder.py
    db.py
"""

from __future__ import annotations

import shutil
import sys
from datetime import datetime
from pathlib import Path

PATCH_ROOT = Path(__file__).resolve().parent / "clipfusion_patch"

FILES = {
    "core/transcriber.py": PATCH_ROOT / "core" / "transcriber.py",
    "core/prompt_builder.py": PATCH_ROOT / "core" / "prompt_builder.py",
    "db.py": PATCH_ROOT / "db.py",
}


def fail(msg: str, code: int = 1) -> None:
    print(f"ERRO: {msg}")
    raise SystemExit(code)


def main() -> None:
    if len(sys.argv) != 2:
        fail("uso: python3 apply_clipfusion_patch.py /caminho/para/o/repo", 2)

    repo = Path(sys.argv[1]).expanduser().resolve()
    if not repo.exists() or not repo.is_dir():
        fail(f"pasta não encontrada: {repo}")

    if not (repo / "main.py").exists():
        fail("não encontrei main.py na raiz. Isso não parece ser o repo correto.")

    backup_dir = repo / f"_backup_patch_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    backup_dir.mkdir(parents=True, exist_ok=True)

    print(f"Repo alvo: {repo}")
    print(f"Backup em: {backup_dir}")

    for relative, source in FILES.items():
        target = repo / relative
        if not source.exists():
            fail(f"arquivo do patch ausente: {source}")

        target.parent.mkdir(parents=True, exist_ok=True)

        if target.exists():
            backup_target = backup_dir / relative
            backup_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup_target)
            print(f"[backup] {relative}")

        shutil.copy2(source, target)
        print(f"[ok] {relative}")

    print("\nPatch aplicado com sucesso.")
    print("Próximos passos sugeridos:")
    print("1) abrir a GUI")
    print("2) testar um vídeo curto primeiro")
    print("3) revisar os cortes gerados e os scores no banco")


if __name__ == "__main__":
    main()
