from __future__ import annotations

from typing import Any, Dict

from core.transcribe import transcribe_audio
from core.segment import segment_by_pauses
from core.transcription_quality import score_transcription
from core.decision_engine import evaluate_decision
from core.cut_engine import render_cut


def process_video(video_path: str, output_dir: str, protection_level: str = "basic") -> Dict[str, Any]:
    segments = transcribe_audio(video_path)
    stitched = " ".join(str(s.get("text", "")) for s in segments)
    blocks = segment_by_pauses(stitched)
    quality = score_transcription(stitched)

    cuts = []
    for idx, seg in enumerate(blocks[:1], start=1):
        final_score = evaluate_decision(0.7, 0.6, 0.5, quality)
        if final_score >= 0.5:
            out = render_cut(
                video_path=video_path,
                start=float(seg.get("start", 0.0)),
                end=float(seg.get("end", 18.0)),
                output_dir=output_dir,
                base_name=f"cut_{idx}",
                subtitle_text=str(seg.get("text", "")),
                protection_level=protection_level,
                use_vaapi=True,
            )
            cuts.append({"path": out, "score": final_score})
    return {"segments": len(blocks), "quality": quality, "cuts": cuts}
