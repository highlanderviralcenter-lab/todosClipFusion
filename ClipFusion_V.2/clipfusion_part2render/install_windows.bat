@echo off
setlocal enabledelayedexpansion
echo === ClipFusion Render Installer (Windows) ===
where python >nul 2>nul
if errorlevel 1 (
  echo Python nao encontrado no PATH.
  exit /b 1
)
python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo FFmpeg nao encontrado no PATH.
) else (
  echo FFmpeg encontrado.
)
echo Instalacao concluida.
