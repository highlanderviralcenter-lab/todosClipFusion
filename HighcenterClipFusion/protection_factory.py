from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List

LAYERS = [
    "zoom_dinamico",
    "cor_adaptativa",
    "strip_metadados",
    "reamostragem_audio",
    "ruido_sutil",
    "micro_timewarp",
    "espelho_horizontal",
]

LEVELS: Dict[str, List[str]] = {
    "none": [],
    "basic": ["zoom_dinamico", "cor_adaptativa"],
    "anti_ia": [
        "zoom_dinamico",
        "cor_adaptativa",
        "strip_metadados",
        "reamostragem_audio",
        "ruido_sutil",
    ],
    "maximum": LAYERS,
}


@dataclass
class ProtectionPlan:
    level: str
    video_filters: List[str]
    audio_filters: List[str]
    ffmpeg_flags: List[str]


def build_plan(level: str) -> ProtectionPlan:
    level = level if level in LEVELS else "basic"
    active = LEVELS[level]

    vfilters = []
    afilters = []
    flags = []

    if "zoom_dinamico" in active:
        vfilters.append("scale=iw*1.02:ih*1.02,crop=iw:ih")
    if "cor_adaptativa" in active:
        vfilters.append("eq=contrast=1.03:brightness=0.01:saturation=1.05")
    if "ruido_sutil" in active:
        vfilters.append("noise=alls=4:allf=t+u")
    if "micro_timewarp" in active:
        vfilters.append("setpts=PTS*1.002")
    if "espelho_horizontal" in active:
        vfilters.append("hflip")

    if "reamostragem_audio" in active:
        afilters.append("aresample=44100,atempo=1.0")
    if "strip_metadados" in active:
        flags += ["-map_metadata", "-1", "-map_chapters", "-1"]

    return ProtectionPlan(level=level, video_filters=vfilters, audio_filters=afilters, ffmpeg_flags=flags)
