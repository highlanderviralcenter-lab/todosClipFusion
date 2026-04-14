def build_ai_evasion_filters(level: str) -> list[str]:
    return ["noise=alls=4:allf=t"] if level in {"anti_ia", "maximum"} else []
