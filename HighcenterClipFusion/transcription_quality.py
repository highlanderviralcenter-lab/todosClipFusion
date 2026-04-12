from __future__ import annotations

from utils import clamp, safe_float


def score_transcription(confidence: float, noise_level: float) -> float:
    conf = clamp(safe_float(confidence))
    noise = clamp(safe_float(noise_level))
    return clamp((conf * 0.8) + ((1.0 - noise) * 0.2))
