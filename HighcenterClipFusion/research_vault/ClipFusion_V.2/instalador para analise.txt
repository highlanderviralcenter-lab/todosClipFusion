#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${HOME}/ClipFusion_V.2"
VENV_DIR="${PROJECT_DIR}/venv"
WORKSPACE_DIR="${PROJECT_DIR}/workspace"
PROJECTS_DIR="${WORKSPACE_DIR}/projects"
LOGS_DIR="${WORKSPACE_DIR}/logs"
CACHE_DIR="${WORKSPACE_DIR}/cache"
MODELS_DIR="${WORKSPACE_DIR}/models"

PYTHON_BIN="${PYTHON_BIN:-python3}"
USE_ZRAM="${USE_ZRAM:-1}"
SET_GUC="${SET_GUC:-1}"

green() { printf "\033[1;32m%s\033[0m\n" "$1"; }
yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
red() { printf "\033[1;31m%s\033[0m\n" "$1"; }

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    yellow "Algumas etapas pedem senha de sudo."
  fi
}

ensure_project_dir() {
  if [ ! -d "$PROJECT_DIR" ]; then
    red "Pasta do projeto não encontrada: $PROJECT_DIR"
    exit 1
  fi
  cd "$PROJECT_DIR"
}

install_system_packages() {
  green "[1/8] Instalando dependências do sistema..."
  sudo apt update
  sudo apt install -y \
    ffmpeg \
    python3 \
    python3-venv \
    python3-pip \
    python3-dev \
    build-essential \
    git \
    curl \
    jq \
    sqlite3 \
    libsqlite3-dev \
    vainfo \
    intel-media-va-driver \
    i965-va-driver \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    libgl1 \
    libglib2.0-0 \
    pkg-config \
    bc \
    unzip
}

create_workspace() {
  green "[2/8] Criando estrutura de pastas..."
  mkdir -p "$PROJECTS_DIR" "$LOGS_DIR" "$CACHE_DIR" "$MODELS_DIR"
}

create_venv() {
  green "[3/8] Criando ambiente virtual..."
  if [ ! -d "$VENV_DIR" ]; then
    "$PYTHON_BIN" -m venv "$VENV_DIR"
  fi

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  python -m pip install --upgrade pip setuptools wheel

  if [ -f requirements.txt ]; then
    green "Instalando requirements.txt..."
    pip install -r requirements.txt
  else
    yellow "requirements.txt não encontrado. Instalando base mínima."
    pip install \
      faster-whisper \
      torch \
      torchaudio \
      numpy \
      tqdm \
      ffmpeg-python \
      pydantic
  fi
}

write_env_file() {
  green "[4/8] Gravando .env local..."
  cat > "${PROJECT_DIR}/.env" <<EOF
CLIPFUSION_PROJECT_DIR=${PROJECT_DIR}
CLIPFUSION_WORKSPACE=${WORKSPACE_DIR}
CLIPFUSION_PROJECTS_DIR=${PROJECTS_DIR}
CLIPFUSION_LOGS_DIR=${LOGS_DIR}
CLIPFUSION_CACHE_DIR=${CACHE_DIR}
CLIPFUSION_MODELS_DIR=${MODELS_DIR}
PYTHONUNBUFFERED=1
EOF
}

write_run_script() {
  green "[5/8] Criando run.sh..."
  cat > "${PROJECT_DIR}/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

if [ ! -d venv ]; then
  echo "venv não encontrado. Rode ./instalar_clipfusion_v2_completo.sh primeiro."
  exit 1
fi

source venv/bin/activate

echo "Iniciando ClipFusion Viral Pro..."

if [ -f src/gui/main_gui.py ]; then
  python src/gui/main_gui.py
elif [ -f main.py ]; then
  python main.py
else
  echo "Nenhum entrypoint encontrado."
  exit 1
fi
EOF
  chmod +x "${PROJECT_DIR}/run.sh"
}

write_db_bootstrap() {
  green "[6/8] Criando bootstrap de banco unificado..."
  mkdir -p "${PROJECT_DIR}/src/core"

  cat > "${PROJECT_DIR}/src/core/db_bootstrap.py" <<'EOF'
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
EOF

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  python "${PROJECT_DIR}/src/core/db_bootstrap.py"
}

setup_zram() {
  if [ "$USE_ZRAM" != "1" ]; then
    yellow "[7/8] zRAM desativado por variável USE_ZRAM=0"
    return
  fi

  green "[7/8] Configurando zRAM..."
  sudo apt install -y zram-tools

  sudo mkdir -p /etc/default
  sudo tee /etc/default/zramswap >/dev/null <<'EOF'
ALGO=lz4
PERCENT=75
PRIORITY=100
EOF

  sudo systemctl enable zramswap || true
  sudo systemctl restart zramswap || true
}

setup_intel_guc() {
  if [ "$SET_GUC" != "1" ]; then
    yellow "[8/8] i915.enable_guc=3 desativado por variável SET_GUC=0"
    return
  fi

  green "[8/8] Configurando i915.enable_guc=3..."
  if [ -f /etc/default/grub ]; then
    if ! grep -q 'i915.enable_guc=3' /etc/default/grub; then
      sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_guc=3 /' /etc/default/grub
      sudo update-grub
    else
      yellow "Parâmetro i915.enable_guc=3 já presente."
    fi
  else
    yellow "/etc/default/grub não encontrado. Pulei ajuste de kernel."
  fi
}

post_checks() {
  green "Verificações finais:"
  echo
  echo "FFmpeg:"
  ffmpeg -version | head -n 1 || true
  echo
  echo "Python venv:"
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  python --version
  echo
  echo "VA-API:"
  vainfo 2>/dev/null | head -n 20 || true
  echo
  echo "Estrutura:"
  ls -la "$PROJECT_DIR" | sed -n '1,20p'
  echo
  green "Instalação concluída."
  yellow "Reinicie o sistema para garantir kernel/GUC/zRAM ativos."
  yellow "Depois rode: ./run.sh"
}

main() {
  require_sudo
  ensure_project_dir
  install_system_packages
  create_workspace
  create_venv
  write_env_file
  write_run_script
  write_db_bootstrap
  setup_zram
  setup_intel_guc
  post_checks
}

main "$@"
