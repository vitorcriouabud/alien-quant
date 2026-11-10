import os
from pathlib import Path
from datetime import datetime

base = Path(r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB")

results = []
for p in base.rglob("*"):
    if ".git" in p.parts:
        continue
    name_lower = p.name.lower()
    if p.is_file() and any(k in name_lower for k in [".log", "result", "output", ".htm", ".csv"]):
        stat = p.stat()
        mtime = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        rel = p.relative_to(base)
        results.append((mtime, stat.st_size, str(rel)))

results.sort(key=lambda x: x[0])
print(f"Total candidate artifacts: {len(results)}")
for mtime, size, path in results[-35:]:
    print(f"{mtime} | {size:>10} bytes | {path}")
