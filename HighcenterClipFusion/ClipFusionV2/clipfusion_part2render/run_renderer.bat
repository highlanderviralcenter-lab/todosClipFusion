@echo off
call .venv\Scripts\activate.bat
python src\render_pipeline.py --video "%~1" --cuts "%~2" --output "%~3"
