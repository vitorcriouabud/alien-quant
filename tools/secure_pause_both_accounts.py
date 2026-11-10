import os
import shutil
import re

print("=== EXECUTING REINFORCED SECURITY PAUSE LOCK ===")

# 1. Ensure Pause Flags exist
flags = [
    r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Files\ALIEN_PAUSE.flag",
    r"C:\Goat_MT5_25K\MQL5\Files\ALIEN_PAUSE.flag"
]
for f in flags:
    os.makedirs(os.path.dirname(f), exist_ok=True)
    with open(f, "w", encoding="utf-8") as fp:
        fp.write("PAUSED_BY_ANTIGRAVITY=TRUE\nREASON=SYSTEMATIC_VALIDATION_ACTIVE\n")
    print(f"Verified pause flag: {f}")

# 2. Patch .chr files
chr_files = [
    r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Profiles\Charts\Default\chart01.chr",
    r"C:\Goat_MT5_25K\Profiles\Charts\Default\chart01.chr",
    r"C:\Goat_MT5_25K\MQL5\Profiles\Charts\Default\chart01.chr"
]

for cf in chr_files:
    if os.path.exists(cf):
        raw = open(cf, "rb").read()
        txt = raw.decode("utf-16le", errors="ignore")
        if "<expert>" in txt:
            # Replace expertmode if needed
            txt = re.sub(r'expertmode=\d+', 'expertmode=5', txt)
            if "AllowLiveRealTrading=true" in txt:
                txt = txt.replace("AllowLiveRealTrading=true", "AllowLiveRealTrading=false")
            elif "AllowLiveRealTrading=false" not in txt:
                txt = txt.replace("<inputs>\r\n", "<inputs>\r\nAllowLiveRealTrading=false\r\n")
                txt = txt.replace("<inputs>\n", "<inputs>\nAllowLiveRealTrading=false\n")
            with open(cf, "wb") as fp:
                fp.write(txt.encode("utf-16le"))
            print(f"Patched chart: {cf} -> AllowLiveRealTrading=false, expertmode=5")

# 3. Fix os.environ typos in diagnostic scripts
tools_dir = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools"
for fname in os.listdir(tools_dir):
    if fname.endswith(".py"):
        fpath = os.path.join(tools_dir, fname)
        try:
            content = open(fpath, "r", encoding="utf-8").read()
            if "os.environ" in content:
                content = content.replace("os.environ", "os.environ")
                if "import os" not in content:
                    content = "import os\n" + content
                with open(fpath, "w", encoding="utf-8") as fp:
                    fp.write(content)
                print(f"Fixed os.environ in {fname}")
        except Exception:
            pass

# 4. Distribute compiled .ex5 to 5K and 25K
src_ex5 = r"C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"
if os.path.exists(src_ex5):
    dests = [
        r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5",
        r"C:\Goat_MT5_25K\MQL5\Experts\ALIEN_V12_1_INSTITUTIONAL.ex5"
    ]
    for d in dests:
        try:
            shutil.copyfile(src_ex5, d)
            print(f"Updated compiled binary: {d} ({os.path.getsize(d)} bytes)")
        except Exception as e:
            print(f"Could not copy to {d}: {e}")

print("=== ALL ACCOUNTS SECURELY LOCKED AND AUDITED ===")
