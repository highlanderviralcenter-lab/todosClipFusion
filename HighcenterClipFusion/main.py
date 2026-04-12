from __future__ import annotations

import argparse
from config import OUTPUT_DIR
from db import init_db
from cut_engine import render_cut


def main() -> None:
    parser = argparse.ArgumentParser(description="HighcenterClipFusion runner")
    parser.add_argument("--video", required=False, help="caminho do vídeo")
    parser.add_argument("--start", type=float, default=0.0)
    parser.add_argument("--end", type=float, default=30.0)
    parser.add_argument("--name", default="cut_demo")
    parser.add_argument("--protection", default="basic", choices=["none", "basic", "anti_ia", "maximum"])
    args = parser.parse_args()

    init_db()
    if args.video:
        outputs = render_cut(args.video, args.start, args.end, str(OUTPUT_DIR), args.name, args.protection)
        print("Render concluído:")
        for k, v in outputs.items():
            print(f"- {k}: {v}")
    else:
        print("DB inicializado em", OUTPUT_DIR.parent / "data" / "highcenter_clipfusion.db")
        print("Passe --video para renderizar um corte de teste.")


if __name__ == "__main__":
    main()
