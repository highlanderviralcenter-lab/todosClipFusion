from __future__ import annotations

from dataclasses import dataclass
from utils import clamp, safe_float


@dataclass
class DecisionResult:
    final_score: float
    decision: str
    reason: str


def evaluate_decision(
    local_score: float,
    external_score: float,
    platform_fit: float,
    transcription_quality: float,
) -> DecisionResult:
    """Regra de Ouro obrigatória.

    (local_score * 0.5) + (external_score * 0.3) + (platform_fit * 0.1) + (transcription_quality * 0.1)
    """
    l = clamp(safe_float(local_score))
    e = clamp(safe_float(external_score))
    p = clamp(safe_float(platform_fit))
    t = clamp(safe_float(transcription_quality))

    final_score = (l * 0.5) + (e * 0.3) + (p * 0.1) + (t * 0.1)

    if final_score >= 0.75:
        return DecisionResult(final_score, "approve", "Score alto no veredito híbrido")
    if final_score >= 0.55:
        return DecisionResult(final_score, "review", "Score intermediário, revisar editorialmente")
    return DecisionResult(final_score, "discard", "Score baixo")
