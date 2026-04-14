from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
items = []
for p in sorted(root.rglob('*')):
    if p.is_file():
        b = p.read_bytes()
        items.append({"path": str(p.relative_to(root)), "sha256": hashlib.sha256(b).hexdigest(), "size": len(b)})
print(json.dumps(items, ensure_ascii=False, indent=2))
