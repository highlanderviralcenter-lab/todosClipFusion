from __future__ import annotations

import json
from typing import Dict


def build_external_payload(candidate: Dict) -> str:
    payload = {
        "start": candidate.get("start"),
        "end": candidate.get("end"),
        "text": candidate.get("text", ""),
        "local_score": candidate.get("local_score", 0.0),
        "need": "Retorne external_score [0..1] e notas editoriais.",
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)


def parse_external_response(raw: str) -> Dict:
    data = json.loads(raw)
    return {
        "external_score": float(data.get("external_score", 0.0) or 0.0),
        "notes": data.get("notes", ""),
    }
