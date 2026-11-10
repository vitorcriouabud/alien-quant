import os

for path in [
    r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\MQL5\Profiles\Charts\Default\order.wnd",
    r"C:\Goat_MT5_25K\Profiles\Charts\Default\order.wnd",
    r"C:\Goat_MT5_25K\MQL5\Profiles\Charts\Default\order.wnd"
]:
    if os.path.exists(path):
        raw = open(path, "rb").read()
        txt = raw.decode("utf-16le", errors="ignore")
        print(f"--- {path} ---")
        print(txt)
