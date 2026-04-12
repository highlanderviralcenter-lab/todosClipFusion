from __future__ import annotations

from typing import Dict, List


def segment_by_pauses(
    segments: List[Dict],
    min_duration: float = 18.0,
    max_duration: float = 35.0,
    pause_threshold: float = 0.5,
) -> List[Dict]:
    """Micro-segmentação orientada por pausas naturais (0.5s)."""
    candidates: List[Dict] = []
    current_start = None
    current_end = None
    current_text: List[str] = []
    last_end = 0.0

    for seg in segments:
        start = float(seg.get("start", 0.0))
        end = float(seg.get("end", start))
        text = str(seg.get("text", "")).strip()
        if not text:
            continue

        if current_start is None:
            current_start = start
            current_end = end
            current_text = [text]
            last_end = end
            continue

        gap = start - last_end
        predicted_duration = end - current_start

        if gap >= pause_threshold or predicted_duration > max_duration:
            dur = current_end - current_start
            if min_duration <= dur <= max_duration:
                candidates.append(
                    {"start": current_start, "end": current_end, "text": " ".join(current_text)}
                )
            current_start = start
            current_end = end
            current_text = [text]
        else:
            current_end = end
            current_text.append(text)

        last_end = end

    if current_start is not None and current_end is not None:
        dur = current_end - current_start
        if min_duration <= dur <= max_duration:
            candidates.append({"start": current_start, "end": current_end, "text": " ".join(current_text)})

    return candidates
