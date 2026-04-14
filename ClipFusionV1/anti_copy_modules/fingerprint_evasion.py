def build_fingerprint_filters(level: str) -> list[str]:
    return ["eq=contrast=1.03:brightness=0.01"] if level != "none" else []
