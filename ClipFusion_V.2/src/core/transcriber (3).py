"""Core — Transcrição Whisper via Python API."""

import gc
import os
import shutil
import subprocess
import tempfile
from typing import Any, Callable, Dict, Optional


def fmt_time(s: float) -> str:
    return f"{int(s // 3600):02d}:{int((s % 3600) // 60):02d}:{int(s % 60):02d}"


class WhisperTranscriber:
    """
    Wrapper simples do Whisper para o pipeline do ClipFusion.

    Regras importantes:
    - language=None ou "auto" => autodetecção do Whisper
    - mantém a extração WAV via ffmpeg, que já está estável no projeto
    """

    def __init__(self, model: str = "base", language: Optional[str] = "auto"):
        self.model = model or "base"
        self.language = language

        try:
            import whisper
            self._whisper = whisper
        except ImportError as exc:
            raise RuntimeError(
                "Whisper não instalado. Execute: pip install openai-whisper"
            ) from exc

    def _log(self, progress_callback: Optional[Callable[[str], None]], msg: str) -> None:
        if progress_callback:
            progress_callback(msg)
        print(msg)

    def _extract_wav(self, video_path: str, wav_path: str) -> None:
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            video_path,
            "-vn",
            "-acodec",
            "pcm_s16le",
            "-ar",
            "16000",
            "-ac",
            "1",
            wav_path,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            stderr = (result.stderr or "").strip()
            raise RuntimeError(f"FFmpeg erro: {stderr[-400:]}")

    def _build_transcribe_kwargs(self) -> Dict[str, Any]:
        kwargs: Dict[str, Any] = {
            "fp16": False,
            "condition_on_previous_text": True,
            "verbose": False,
            "no_speech_threshold": 0.6,
            "logprob_threshold": -1.0,
        }

        # Auto = não enviar language ao Whisper.
        if self.language not in (None, "", "auto"):
            kwargs["language"] = self.language

        return kwargs

    def transcribe(self, video_path: str, progress_callback=None) -> dict:
        tmp_dir = tempfile.mkdtemp(prefix="clipfusion_whisper_")
        wav_path = os.path.join(tmp_dir, "audio.wav")
        model = None

        try:
            self._log(progress_callback, "🎧 Extraindo áudio (16kHz mono)...")
            self._extract_wav(video_path, wav_path)

            self._log(
                progress_callback,
                f"🧠 Transcrevendo com Whisper '{self.model}'"
                + (
                    " (autodetectando idioma)..."
                    if self.language in (None, "", "auto")
                    else f" (idioma={self.language})..."
                ),
            )

            model = self._whisper.load_model(self.model, device="cpu")
            result = model.transcribe(wav_path, **self._build_transcribe_kwargs())

            segments = []
            for seg in result.get("segments", []) or []:
                start = round(float(seg.get("start", 0.0)), 2)
                end = round(float(seg.get("end", 0.0)), 2)
                text = str(seg.get("text", "")).strip()
                if not text or end <= start:
                    continue
                segments.append(
                    {
                        "start": start,
                        "end": end,
                        "text": text,
                    }
                )

            detected_language = result.get("language")
            if not detected_language:
                detected_language = "auto" if self.language in (None, "", "auto") else self.language

            self._log(progress_callback, f"✅ {len(segments)} segmentos transcritos.")

            return {
                "full_text": " ".join(s["text"] for s in segments).strip(),
                "segments": segments,
                "language": detected_language,
            }

        finally:
            try:
                if model is not None:
                    del model
            except Exception:
                pass
            gc.collect()
            shutil.rmtree(tmp_dir, ignore_errors=True)


def transcribe(
    video_path: str,
    model: str = "base",
    language: Optional[str] = "auto",
    progress_cb=None,
) -> dict:
    return WhisperTranscriber(model, language).transcribe(video_path, progress_cb)
