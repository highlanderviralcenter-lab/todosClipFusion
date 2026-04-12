from __future__ import annotations

from utils import clamp


def platform_fit_score(text: str, platform: str) -> float:
    text = (text or "").lower()
    score = 0.5
    if platform == "tiktok":
        if "story" in text or "plot twist" in text:
            score += 0.2
    elif platform == "reels":
        if "tutorial" in text or "before" in text:
            score += 0.2
    elif platform == "shorts":
        if "fact" in text or "did you know" in text:
            score += 0.2
    return clamp(score)
