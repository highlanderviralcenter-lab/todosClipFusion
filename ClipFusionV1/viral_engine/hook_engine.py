from .archetypes import EMOTIONAL_TRIGGERS_BY_NICHE

def suggest_hooks(niche: str) -> list[str]:
    return EMOTIONAL_TRIGGERS_BY_NICHE.get(niche.lower(), EMOTIONAL_TRIGGERS_BY_NICHE["geral"])
