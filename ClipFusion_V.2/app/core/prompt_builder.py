"""ClipFusion — Prompt Builder para IA externa."""
import json, re
from viral_engine.archetypes import ARCHETYPES
from core.transcriber import fmt_time


def build_analysis_prompt(segments: list, duration: float, context: str = "") -> str:
    lines, total = [], 0
    for s in segments:
        line = f"[{fmt_time(s['start'])}] {s['text']}"
        total += len(line)
        if total > 12000:
            lines.append("...(truncado)")
            break
        lines.append(line)
    transcript = "\n".join(lines)
    arch_block = "\n".join(
        f"  {k}: {v['emocao']} — {v['descricao']}"
        for k, v in ARCHETYPES.items())
    ctx = f"\n## CONTEXTO\n{context.strip()}\n" if context.strip() else ""

    return f"""Você é especialista em engenharia de retenção e viralização de conteúdo curto.
{ctx}
## DURAÇÃO TOTAL: {fmt_time(duration)}

## TRANSCRIÇÃO COM TIMESTAMPS
{transcript}

## ARQUÉTIPOS DISPONÍVEIS
{arch_block}

## PLATAFORMAS
  tiktok: vertical 9:16, ideal 30–60s, máx 180s. Gancho nos primeiros 1–2s.
  reels: vertical 9:16, ideal 15–60s, máx 90s.
  shorts: vertical 9:16, máx 60s.

## TAREFA
Identifique de 3 a 8 cortes com alto potencial viral.
Critérios: gancho forte nos primeiros 3s, valor emocional claro, 20–90s de duração.

## RESPOSTA — SOMENTE JSON, SEM MARKDOWN

{{
  "cortes": [
    {{
      "titulo": "título (máx 60 chars)",
      "start": 123.4,
      "end": 187.2,
      "archetype": "05_revelacao",
      "hook": "o que prende nos primeiros 3 segundos",
      "reason": "por que vai viralizar (2 frases)",
      "platforms": ["tiktok", "reels", "shorts"],
      "metadata": {{
        "titulo_post": "título para publicação",
        "descricao": "2–3 frases",
        "hashtags": ["#tag1", "#tag2", "#tag3", "#tag4", "#tag5"]
      }}
    }}
  ]
}}

Analise agora:"""


def parse_ai_response(text: str) -> list:
    text  = re.sub(r"```json\s*|```\s*", "", text.strip())
    match = re.search(r'\{[\s\S]*\}', text)
    if not match:
        raise ValueError("Nenhum JSON encontrado.")
    cortes = json.loads(match.group()).get("cortes", [])
    result = []
    for i, c in enumerate(cortes):
        s, e = float(c.get("start", 0)), float(c.get("end", 0))
        if e > s and (e - s) >= 10:
            result.append({
                "cut_index": i, "title": c.get("titulo", f"Corte {i+1}"),
                "start": s, "end": e,
                "archetype": c.get("archetype", "01_despertar"),
                "hook": c.get("hook", ""), "reason": c.get("reason", ""),
                "platforms": c.get("platforms", ["tiktok", "reels", "shorts"]),
                "metadata": c.get("metadata", {}),
            })
    return result
