import os

for path in [
    r"C:\Goat_MT5_25K\Config\servers.dat",
    r"C:\Program Files\Goat Funded MT5 Terminal\Config\servers.dat",
    r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\config\servers.dat"
]:
    if os.path.exists(path):
        raw = open(path, "rb").read()
        print(f"\n--- {path} ({len(raw)} bytes) ---")
        # search for server names in ascii or utf-16
        for enc in ["utf-16le", "ascii"]:
            try:
                # find matches
                import re
                s = raw.decode(enc, errors="ignore")
                matches = set(re.findall(r"Goat[A-Za-z0-9_\-]+", s))
                print(f"  Matches ({enc}): {matches}")
            except Exception as e:
                pass
    else:
        print(f"Path does not exist: {path}")
