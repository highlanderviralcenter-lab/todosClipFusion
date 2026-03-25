import gc
from faster_whisper import WhisperModel
import db

class Transcriber:
    def __init__(self, model_size="base", device="cpu", compute_type="int8"):
        self.model_size = model_size
        self.device = device
        self.compute_type = compute_type
        self.model = None

    def _load_model(self):
        if self.model is None:
            self.model = WhisperModel(self.model_size, device=self.device, compute_type=self.compute_type)

    def transcribe(self, audio_path, language=None, beam_size=5, best_of=5, temperature=0.0):
        self._load_model()
        segments, info = self.model.transcribe(
            audio_path,
            language=language,
            beam_size=beam_size,
            best_of=best_of,
            temperature=temperature,
            condition_on_previous_text=True,
            compression_ratio_threshold=2.4,
            logprob_threshold=-1.0,
            no_speech_threshold=0.6,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        detected_language = info.language
        segments_list = [
            {"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text}
            for s in segments
        ]
        full_text = " ".join(s["text"] for s in segments_list)
        return {
            "language": detected_language,
            "segments": segments_list,
            "full_text": full_text,
            "info": info
        }

    def cleanup(self):
        del self.model
        self.model = None
        gc.collect()

def transcribe_project(project_id, video_path, model_size="base", language="pt"):
    transcriber = Transcriber(model_size=model_size)
    result = transcriber.transcribe(video_path, language=language)
    transcript_id = db.save_transcript(project_id, result["full_text"], result["segments"])
    transcriber.cleanup()
    return transcript_id, result
