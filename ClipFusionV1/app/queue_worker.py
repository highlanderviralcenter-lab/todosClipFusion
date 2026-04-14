from __future__ import annotations

from infra.db import init_db, enqueue_job, fetch_next_job, finish_job, fail_job
from app.pipeline import process_video


def run_once(output_dir: str) -> bool:
    init_db()
    job = fetch_next_job()
    if not job:
        return False
    job_id, video_path = job
    try:
        process_video(video_path, output_dir=output_dir)
        finish_job(job_id)
    except Exception as err:
        fail_job(job_id, str(err))
    return True


def enqueue(video_path: str) -> None:
    init_db()
    enqueue_job(video_path)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--enqueue", default="")
    parser.add_argument("--output-dir", default="output/renders")
    args = parser.parse_args()

    if args.enqueue:
        enqueue(args.enqueue)
        print("enqueued", args.enqueue)
    else:
        while run_once(args.output_dir):
            pass
        print("queue drained")
