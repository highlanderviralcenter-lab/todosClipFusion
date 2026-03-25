import argparse, json, re, subprocess, sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List
from tqdm import tqdm

@dataclass
class Cut:
    titulo: str
    start: float
    end: float

def sanitize_filename(name: str, max_len: int = 80) -> str:
    name = re.sub(r"[^\w\s\-\(\)\[\]]+", "", name, flags=re.UNICODE)
    name = re.sub(r"\s+", "_", name.strip())
    return name[:max_len] or "corte"

def ensure_ffmpeg() -> None:
    subprocess.run(["ffmpeg", "-version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

def load_cuts(cuts_path: Path) -> List[Cut]:
    data = json.loads(cuts_path.read_text(encoding="utf-8"))
    raw = data["cortes"] if isinstance(data, dict) and "cortes" in data else data
    out = []
    for item in raw:
        start = float(item["start"])
        end = float(item["end"])
        if end > start:
            out.append(Cut(str(item.get("titulo") or item.get("title") or f"corte_{len(out)+1}"), start, end))
    return out

def ffmpeg_command(video: Path, start: float, end: float, output: Path):
    duration = max(0.1, end - start)
    vf = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=30,format=yuv420p"
    return ["ffmpeg","-y","-ss",f"{start}","-i",str(video),"-t",f"{duration}","-vf",vf,"-c:v","libx264","-preset","medium","-crf","20","-c:a","aac","-b:a","192k","-movflags","+faststart",str(output)]

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--video", required=True)
    p.add_argument("--cuts", required=True)
    p.add_argument("--output", required=True)
    a = p.parse_args()
    video = Path(a.video)
    cuts_path = Path(a.cuts)
    output_dir = Path(a.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    ensure_ffmpeg()
    cuts = load_cuts(cuts_path)
    results = []
    for i, cut in enumerate(tqdm(cuts, unit="corte"), start=1):
        out = output_dir / f"{i:02d}_{sanitize_filename(cut.titulo)}.mp4"
        cmd = ffmpeg_command(video, cut.start, cut.end, out)
        cp = subprocess.run(cmd, capture_output=True, text=True)
        results.append({"index": i, "titulo": cut.titulo, "start": cut.start, "end": cut.end, "output_file": str(out), "status": "ok" if cp.returncode == 0 else "error", "error": None if cp.returncode == 0 else cp.stderr[-2000:]})
    (output_dir / "render_log.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Concluído")
if __name__ == "__main__":
    main()
