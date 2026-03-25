#!/bin/bash
# capture_errors.sh - Salva TODOS os erros do terminal

LOG_DIR="$HOME/ClipFusion_V.2/src/logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/error_${TIMESTAMP}.log"

# Cabeçalho
echo "══════════════════════════════════════════════════════════" > "$LOG_FILE"
echo "CLIPFUSION ERROR LOG" >> "$LOG_FILE"
echo "Data: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "══════════════════════════════════════════════════════════" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Executa e captura TUDO (stdout + stderr)
"$@" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

# Se deu erro, adiciona info do sistema
if [ $EXIT_CODE -ne 0 ]; then
    echo "" >> "$LOG_FILE"
    echo "══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "SYSTEM INFO" >> "$LOG_FILE"
    echo "══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "Memória:" >> "$LOG_FILE"
    free -h >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "ZRAM:" >> "$LOG_FILE"
    cat /proc/swaps >> "$LOG_FILE" 2>/dev/null || echo "N/A" >> "$LOG_FILE"
fi

exit $EXIT_CODE
