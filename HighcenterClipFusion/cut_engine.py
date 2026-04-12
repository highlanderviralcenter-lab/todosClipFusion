from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Dict

from protection_factory import build_plan

PLATFORM_CONFIGS = {
    "tiktok": {"w": 1080, "h": 1920, "fps": 30, "crf": 20, "preset": "fast", "abr": "128k", "suffix": "_tiktok"},
    "reels": {"w": 1080, "h": 1920, "fps": 30, "crf": 21, "preset": "fast", "abr": "128k", "suffix": "_reels"},
    "shorts": {"w": 1080, "h": 1920, "fps": 30, "crf": 21, "preset": "fast", "abr": "128k", "suffix": "_shorts"},
}


def _detect_vaapi() -> bool:
    try:
        proc = subprocess.run(["vainfo"], capture_output=True, text=True)
        return "VAEntrypointEncSlice" in proc.stdout
    except FileNotFoundError:
        return False


def _ms(s: float) -> str:
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    return f"{int(h):02d}:{int(m):02d}:{int(sec):02d},{int((s % 1) * 1000):03d}"


def _build_srt(text: str, duration: float) -> str:
    return f"1\n{_ms(0.0)} --> {_ms(duration)}\n{text.strip()}\n"


def _apply_plan(input_path: str, output_path: str, level: str) -> None:
    plan = build_plan(level)
    cmd = ["ffmpeg", "-y", "-i", input_path]
    if plan.video_filters:
        cmd += ["-vf", ",".join(plan.video_filters)]
    if plan.audio_filters:
        cmd += ["-af", ",".join(plan.audio_filters)]
    cmd += plan.ffmpeg_flags
    cmd += ["-c:v", "libx264", "-preset", "fast", "-crf", "21", "-c:a", "aac", output_path]
    subprocess.run(cmd, check=True)


def render_cut(
    video_path: str,
    start: float,
    end: float,
    out_dir: str,
    base_name: str,
    protection_level: str = "basic",
    subtitle_text: str = "",
    use_vaapi: bool = True,
) -> Dict[str, str]:
    """Render 2-pass real: pass 1 (VA-API) + pass 2 (libx264 com legenda)."""
    duration = max(0.1, float(end) - float(start))
    out = {}
    vaapi_ok = _detect_vaapi() and use_vaapi
    tmp = tempfile.mkdtemp(prefix="hcf_")

    try:
        srt_path = Path(tmp) / "sub.srt"
        has_subs = bool(subtitle_text.strip())
        if has_subs:
            srt_path.write_text(_build_srt(subtitle_text, duration), encoding="utf-8")
            srt_esc = str(srt_path).replace("\\", "/").replace(":", "\\:")
        else:
            srt_esc = ""

        for platform, cfg in PLATFORM_CONFIGS.items():
            base = Path(out_dir) / platform
            base.mkdir(parents=True, exist_ok=True)
            raw = Path(tmp) / f"{platform}_raw.mp4"
            final = base / f"{base_name}{cfg['suffix']}.mp4"

            if vaapi_ok:
                pass1 = [
                    "ffmpeg", "-y",
                    "-hwaccel", "vaapi", "-hwaccel_device", "/dev/dri/renderD128",
                    "-ss", str(start), "-i", video_path, "-t", str(duration),
                    "-vf", f"scale={cfg['w']}:{cfg['h']}:force_original_aspect_ratio=decrease,pad={cfg['w']}:{cfg['h']}:(ow-iw)/2:(oh-ih)/2:black,format=nv12,hwupload,scale_vaapi={cfg['w']}:{cfg['h']}",
                    "-c:v", "h264_vaapi", "-c:a", "aac", "-b:a", cfg["abr"], "-r", str(cfg["fps"]),
                    str(raw),
                ]
                subprocess.run(pass1, check=True)

                if has_subs:
                    vf = f"subtitles='{srt_esc}':force_style='FontName=Arial,FontSize=22,Outline=2,Shadow=1,Alignment=2,MarginV=60'"
                    pass2 = [
                        "ffmpeg", "-y", "-i", str(raw),
                        "-vf", vf,
                        "-c:v", "libx264", "-preset", cfg["preset"], "-crf", str(cfg["crf"]),
                        "-c:a", "copy", "-pix_fmt", "yuv420p", str(final),
                    ]
                else:
                    pass2 = [
                        "ffmpeg", "-y", "-i", str(raw),
                        "-c:v", "libx264", "-preset", cfg["preset"], "-crf", str(cfg["crf"]),
                        "-c:a", "copy", "-pix_fmt", "yuv420p", str(final),
                    ]
                subprocess.run(pass2, check=True)
            else:
                scale = f"scale={cfg['w']}:{cfg['h']}:force_original_aspect_ratio=decrease,pad={cfg['w']}:{cfg['h']}:(ow-iw)/2:(oh-ih)/2:black"
                vf = f"{scale},subtitles='{srt_esc}'" if has_subs else scale
                cpu = [
                    "ffmpeg", "-y", "-ss", str(start), "-i", video_path, "-t", str(duration),
                    "-vf", vf,
                    "-c:v", "libx264", "-preset", cfg["preset"], "-crf", str(cfg["crf"]),
                    "-c:a", "aac", "-b:a", cfg["abr"], "-pix_fmt", "yuv420p", str(final),
                ]
                subprocess.run(cpu, check=True)

            if protection_level != "none":
                protected = base / f"{base_name}{cfg['suffix']}_protected.mp4"
                _apply_plan(str(final), str(protected), protection_level)
                final.unlink(missing_ok=True)
                shutil.move(str(protected), str(final))

            out[platform] = str(final)

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    return out
