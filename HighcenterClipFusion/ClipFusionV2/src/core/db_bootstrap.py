from pathlib import Path
import sqlite3
import os

DB_PATH = Path(os.getenv("CLIPFUSION_WORKSPACE", ".")) / "clipfusion.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  video_path TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transcripts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER,
  language TEXT,
  full_text TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS candidates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER,
  start REAL,
  end REAL,
  title TEXT,
  hook_score REAL DEFAULT 0,
  retention_score REAL DEFAULT 0,
  moment_score REAL DEFAULT 0,
  final_score REAL DEFAULT 0,
  archetype TEXT,
  approved INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS render_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER,
  candidate_id INTEGER,
  status TEXT,
  output_path TEXT,
  error_log TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
"""

def main():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)
    conn.commit()
    conn.close()
    print(f"Banco inicializado em: {DB_PATH}")

if __name__ == "__main__":
    main()
