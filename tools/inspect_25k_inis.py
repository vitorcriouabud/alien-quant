import os

for fname in ["settings.ini", "terminal.ini", "common.ini"]:
    p = os.path.join(r"C:\Goat_MT5_25K\Config", fname)
    if os.path.exists(p):
        raw = open(p, "rb").read()
        print(f"\n=== {fname} ({len(raw)} bytes) ===")
        for enc in ["utf-16le", "utf-8", "cp1252"]:
            try:
                txt = raw.decode(enc)
                print(f"Decoded {enc}:")
                for l in txt.splitlines()[:25]:
                    print("  ", l)
                break
            except Exception:
                pass
