import os

chr_path = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Profiles\Charts\Default\chart01.chr"
raw = open(chr_path, "rb").read()
print(f"File size: {len(raw)} bytes")
# Try encodings
for enc in ["utf-16", "utf-8", "cp1252"]:
    try:
        t = raw.decode(enc)
        print(f"Decoded with {enc}: len={len(t)}")
        for l in t.splitlines():
            if "expert" in l.lower() or "alien" in l.lower() or "input" in l.lower() or "lot" in l.lower():
                print("  ", l)
        break
    except Exception as e:
        print(f"Failed {enc}: {e}")
