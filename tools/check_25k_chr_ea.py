import os

for p in [
    r"C:\Goat_MT5_25K\Profiles\Charts\Default\chart01.chr",
    r"C:\Goat_MT5_25K\MQL5\Profiles\Charts\Default\chart01.chr"
]:
    if os.path.exists(p):
        raw = open(p, "rb").read()
        txt = raw.decode("utf-16le", errors="ignore")
        has_ea = "<expert>" in txt
        print(f"{p}: has_ea={has_ea}")
        if has_ea:
            s = txt.find("<expert>")
            e = txt.find("</expert>")
            print(txt[s:e+9])
        else:
            # show last 20 lines
            for l in txt.splitlines()[-15:]:
                print("  ", l)
