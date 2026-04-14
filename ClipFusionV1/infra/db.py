from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from typing import Any, Dict, Iterable, List, Optional

from config import DB_PATH


def _connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


@contextmanager
def get_db():
    conn = _connect()
    try:
        yield conn
    finally:
        conn.close()


def init_db() -> None:
    """Schema unificado com DEFAULT 0.0 para todos os campos de score."""
    with get_db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS projects (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                video_path TEXT NOT NULL,
                status TEXT DEFAULT 'created',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS transcripts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id INTEGER NOT NULL,
                full_text TEXT,
                segments_json TEXT,
                quality_score REAL DEFAULT 0.0,
                asr_confidence REAL DEFAULT 0.0,
                noise_level REAL DEFAULT 0.0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS candidates (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id INTEGER NOT NULL,
                transcript_id INTEGER NOT NULL,
                start_time REAL NOT NULL,
                end_time REAL NOT NULL,
                text TEXT NOT NULL,
                hook_score REAL DEFAULT 0.0,
                retention_score REAL DEFAULT 0.0,
                moment_score REAL DEFAULT 0.0,
                shareability_score REAL DEFAULT 0.0,
                local_score REAL DEFAULT 0.0,
                external_score REAL DEFAULT 0.0,
                platform_fit REAL DEFAULT 0.0,
                transcription_quality REAL DEFAULT 0.0,
                final_score REAL DEFAULT 0.0,
                decision TEXT DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
                FOREIGN KEY (transcript_id) REFERENCES transcripts(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS cuts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id INTEGER NOT NULL,
                candidate_id INTEGER,
                platform TEXT NOT NULL,
                protection_level TEXT DEFAULT 'none',
                output_path TEXT,
                final_score REAL DEFAULT 0.0,
                decision TEXT DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
                FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE SET NULL
            );
            """
        )
        conn.commit()


def _row_to_dict(row: Optional[sqlite3.Row]) -> Optional[Dict[str, Any]]:
    return dict(row) if row else None


def normalize_scores(payload: Optional[Dict[str, Any]]) -> Dict[str, float]:
    payload = dict(payload or {})
    if "retention_score" not in payload and "retencao_estimada" in payload:
        payload["retention_score"] = payload.get("retencao_estimada", 0.0)
    return {
        "hook_score": float(payload.get("hook_score", payload.get("hook", 0.0)) or 0.0),
        "retention_score": float(payload.get("retention_score", 0.0) or 0.0),
        "moment_score": float(payload.get("moment_score", payload.get("moment", 0.0)) or 0.0),
        "shareability_score": float(payload.get("shareability_score", payload.get("shareability", 0.0)) or 0.0),
        "local_score": float(payload.get("local_score", 0.0) or 0.0),
        "external_score": float(payload.get("external_score", 0.0) or 0.0),
        "platform_fit": float(payload.get("platform_fit", 0.0) or 0.0),
        "transcription_quality": float(payload.get("transcription_quality", 0.0) or 0.0),
        "final_score": float(payload.get("final_score", 0.0) or 0.0),
    }


def create_project(name: str, video_path: str) -> int:
    with get_db() as conn:
        cur = conn.execute(
            "INSERT INTO projects (name, video_path) VALUES (?, ?)",
            (name.strip() or "Projeto sem nome", video_path),
        )
        conn.commit()
        return int(cur.lastrowid)


def list_projects() -> List[Dict[str, Any]]:
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM projects ORDER BY id DESC").fetchall()
        return [dict(x) for x in rows]


def get_project(project_id: int) -> Optional[Dict[str, Any]]:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM projects WHERE id = ?", (project_id,)).fetchone()
        return _row_to_dict(row)


def update_project_status(project_id: int, status: str) -> None:
    with get_db() as conn:
        conn.execute("UPDATE projects SET status = ? WHERE id = ?", (status, project_id))
        conn.commit()


def save_transcription(project_id: int, full_text: str, segments: Iterable[Dict[str, Any]], quality_score: float = 0.0) -> int:
    segments_json = json.dumps(list(segments), ensure_ascii=False)
    with get_db() as conn:
        cur = conn.execute(
            """
            INSERT INTO transcripts (project_id, full_text, segments_json, quality_score)
            VALUES (?, ?, ?, ?)
            """,
            (project_id, full_text, segments_json, float(quality_score or 0.0)),
        )
        conn.commit()
        return int(cur.lastrowid)


def get_transcription(project_id: int) -> Optional[Dict[str, Any]]:
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM transcripts WHERE project_id = ? ORDER BY id DESC LIMIT 1",
            (project_id,),
        ).fetchone()
        if not row:
            return None
        out = dict(row)
        out["segments"] = json.loads(out.get("segments_json") or "[]")
        return out


def save_candidate(project_id: int, transcript_id: int, start_time: float, end_time: float, text: str, scores: Optional[Dict[str, Any]] = None, decision: str = "pending") -> int:
    s = normalize_scores(scores)
    with get_db() as conn:
        cur = conn.execute(
            """
            INSERT INTO candidates (
                project_id, transcript_id, start_time, end_time, text,
                hook_score, retention_score, moment_score, shareability_score,
                local_score, external_score, platform_fit, transcription_quality,
                final_score, decision
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                project_id,
                transcript_id,
                float(start_time),
                float(end_time),
                text,
                s["hook_score"],
                s["retention_score"],
                s["moment_score"],
                s["shareability_score"],
                s["local_score"],
                s["external_score"],
                s["platform_fit"],
                s["transcription_quality"],
                s["final_score"],
                decision,
            ),
        )
        conn.commit()
        return int(cur.lastrowid)


def list_candidates(project_id: int) -> List[Dict[str, Any]]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM candidates WHERE project_id = ? ORDER BY final_score DESC, id DESC",
            (project_id,),
        ).fetchall()
        return [dict(r) for r in rows]


def save_cut(project_id: int, candidate_id: int, platform: str, protection_level: str, final_score: float, decision: str = "pending") -> int:
    with get_db() as conn:
        cur = conn.execute(
            """
            INSERT INTO cuts (project_id, candidate_id, platform, protection_level, final_score, decision)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (project_id, candidate_id, platform, protection_level, float(final_score), decision),
        )
        conn.commit()
        return int(cur.lastrowid)


def update_cut_output(cut_id: int, output_path: str, decision: Optional[str] = None) -> None:
    with get_db() as conn:
        if decision is None:
            conn.execute("UPDATE cuts SET output_path = ? WHERE id = ?", (output_path, cut_id))
        else:
            conn.execute(
                "UPDATE cuts SET output_path = ?, decision = ? WHERE id = ?",
                (output_path, decision, cut_id),
            )
        conn.commit()


def list_cuts(project_id: int) -> List[Dict[str, Any]]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM cuts WHERE project_id = ? ORDER BY id DESC", (project_id,)
        ).fetchall()
        return [dict(r) for r in rows]


def _ensure_queue_table(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            video_path TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'queued',
            error TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )


def enqueue_job(video_path: str) -> int:
    with get_db() as conn:
        _ensure_queue_table(conn)
        cur = conn.execute("INSERT INTO jobs (video_path, status) VALUES (?, 'queued')", (video_path,))
        conn.commit()
        return int(cur.lastrowid)


def fetch_next_job() -> Optional[tuple[int, str]]:
    with get_db() as conn:
        _ensure_queue_table(conn)
        row = conn.execute(
            "SELECT id, video_path FROM jobs WHERE status='queued' ORDER BY id ASC LIMIT 1"
        ).fetchone()
        if not row:
            return None
        conn.execute(
            "UPDATE jobs SET status='running', updated_at=CURRENT_TIMESTAMP WHERE id=?",
            (int(row["id"]),),
        )
        conn.commit()
        return int(row["id"]), str(row["video_path"])


def finish_job(job_id: int) -> None:
    with get_db() as conn:
        _ensure_queue_table(conn)
        conn.execute(
            "UPDATE jobs SET status='done', updated_at=CURRENT_TIMESTAMP WHERE id=?",
            (job_id,),
        )
        conn.commit()


def fail_job(job_id: int, error: str) -> None:
    with get_db() as conn:
        _ensure_queue_table(conn)
        conn.execute(
            "UPDATE jobs SET status='error', error=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
            (error[:500], job_id),
        )
        conn.commit()
