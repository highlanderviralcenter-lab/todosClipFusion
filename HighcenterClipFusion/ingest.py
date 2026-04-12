from __future__ import annotations

from pathlib import Path


def validate_video_path(video_path: str) -> Path:
    path = Path(video_path).expanduser().resolve()
    if not path.exists():
        raise FileNotFoundError(f"Vídeo não encontrado: {path}")
    return path
