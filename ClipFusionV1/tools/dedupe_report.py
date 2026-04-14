from collections import defaultdict
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
g = defaultdict(list)
for p in root.rglob('*'):
    if p.is_file():
        g[hashlib.sha256(p.read_bytes()).hexdigest()].append(str(p.relative_to(root)))
for h, paths in g.items():
    if len(paths) > 1:
        print(h, *paths, sep='\n  - ')
