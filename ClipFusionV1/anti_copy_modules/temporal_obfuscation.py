def build_temporal_filters(level: str) -> list[str]:
    return ["setpts=PTS*1.001"] if level in {"anti_ia", "maximum"} else []
