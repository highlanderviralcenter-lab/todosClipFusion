from __future__ import annotations

import argparse
from app.pipeline import process_video


def main() -> None:
    p = argparse.ArgumentParser(description="ClipFusionV1")
    p.add_argument("--video", required=True)
    p.add_argument("--output-dir", default="output/renders")
    p.add_argument("--protection", default="basic")
    args = p.parse_args()
    result = process_video(args.video, args.output_dir, args.protection)
    print(result)


if __name__ == "__main__":
    main()
