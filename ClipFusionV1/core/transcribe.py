from __future__ import annotations

from dataclasses import dataclass
from typing import List, Dict


@dataclass
class TranscriptSegment:
    start: float
    end: float
    text: str


def transcribe_audio(video_path: str, model_size: str = "small") -> List[Dict[str, float | str]]:
    """Transcreve com faster-whisper se disponível; fallback para segmento vazio."""
    try:
        from faster_whisper import WhisperModel  # type: ignore
    except Exception:
        return [{"start": 0.0, "end": 18.0, "text": "Trecho de fallback para análise local."}]

    model = WhisperModel(model_size, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(video_path, vad_filter=True)
    out: List[Dict[str, float | str]] = []
    for seg in segments:
        out.append({"start": float(seg.start), "end": float(seg.end), "text": str(seg.text).strip()})
    return out or [{"start": 0.0, "end": 18.0, "text": "Trecho de fallback para análise local."}]
