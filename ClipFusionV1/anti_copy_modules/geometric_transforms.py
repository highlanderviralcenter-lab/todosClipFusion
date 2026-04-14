def build_geometric_filters(level: str) -> list[str]:
    return ["scale=iw*1.01:ih*1.01,crop=iw/1.01:ih/1.01"] if level != "none" else []
