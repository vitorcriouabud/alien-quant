import os

ini_path = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\Config\common.ini"

# Read as raw bytes or detect encoding
with open(ini_path, "rb") as f:
    raw = f.read()

# Let's inspect raw
# If UTF-16 LE BOM is present (\xff\xfe)
text = raw.decode("utf-16", errors="ignore")

# Remove any duplicate [Charts] or junk at the end
if "[Experts]" in text:
    lines = text.splitlines()
    clean_lines = []
    in_experts = False
    for line in lines:
        if line.strip() == "[Experts]":
            in_experts = True
            clean_lines.append(line)
            continue
        if in_experts:
            if line.startswith("["):
                in_experts = False
            elif line.startswith("Enabled="):
                clean_lines.append("Enabled=1")
                continue
            elif line.startswith("Account="):
                clean_lines.append("Account=0")
                continue
        clean_lines.append(line)
    
    clean_text = "\r\n".join(clean_lines) + "\r\n"
    with open(ini_path, "w", encoding="utf-16") as f:
        f.write(clean_text)
    print("SUCCESS: Fixed common.ini with UTF-16 encoding, Enabled=1, Account=0")
else:
    print("ERROR: [Experts] not found in common.ini")
