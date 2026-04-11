#!/bin/bash
# Fix ClipFusion - Anti-freeze para Intel HD 520
# Copie este arquivo, cole em: ~/clipfusion/fix_clipfusion.sh
# Depois rode: bash fix_clipfusion.sh

cd ~/clipfusion || { echo "Erro: não estou em ~/clipfusion"; exit 1; }

echo "🔧 Corrigindo ClipFusion..."

# Backup
cp core/cut_engine.py core/cut_engine.py.bak
echo "✅ Backup feito"

# Aplica correções no cut_engine.py
python3 << 'EOF'
import re

with open("core/cut_engine.py", "r") as f:
    content = f.read()

# 1. Adicionar threads=2
if '"-threads", "2",' not in content:
    content = content.replace(
        '"-vf", f"scale_vaapi={w}:{h}"',
        '"-threads", "2",\n                    "-vf", f"scale_vaapi={w}:{h}:mode=fast"'
    )
    print("✅ threads=2 adicionado")

# 2. Adicionar qp=25
if '"-qp", "25",' not in content:
    content = content.replace(
        '"-c:v", "h264_vaapi",',
        '"-c:v", "h264_vaapi",\n                    "-qp", "25",'
    )
    print("✅ qp=25 adicionado")

with open("core/cut_engine.py", "w") as f:
    f.write(content)
EOF

# Criar novo run.sh
cat > run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
export LIBVA_DRIVER_NAME=iHD
export LIBVA_MESSAGING_LEVEL=1
export MESA_VK_MEMORY_HEAP_SIZE="1GB"
source venv/bin/activate
python3 main.py
EOF
chmod +x run.sh
echo "✅ run.sh atualizado"

echo ""
echo "🎉 Pronto! Rode: ./run.sh"
