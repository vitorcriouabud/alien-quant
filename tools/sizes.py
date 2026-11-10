import os

D = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79"


def size(d):
    s = 0
    for r, _, fs in os.walk(d):
        for f in fs:
            try:
                s += os.path.getsize(os.path.join(r, f))
            except OSError:
                pass
    return s / 1e6


for name in sorted(os.listdir(D)):
    p = os.path.join(D, name)
    if os.path.isdir(p):
        print(f"{name:20s} {size(p):9.1f} MB")
b = os.path.join(D, "bases")
for name in sorted(os.listdir(b)):
    p = os.path.join(b, name)
    if os.path.isdir(p):
        print("  bases/", name, round(size(p), 1), "MB")
mq = os.path.join(D, "MQL5")
for name in sorted(os.listdir(mq)):
    p = os.path.join(mq, name)
    if os.path.isdir(p):
        print("  MQL5/", name, round(size(p), 1), "MB")
