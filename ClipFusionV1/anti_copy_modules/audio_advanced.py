def build_audio_filters(level: str) -> list[str]:
    return ["volume=1.02"] if level != "none" else []
