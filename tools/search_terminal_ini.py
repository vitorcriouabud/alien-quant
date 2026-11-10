import os

t_ini = r"C:\Goat_MT5_25K\Config\terminal.ini"
raw = open(t_ini, "rb").read()
txt = raw.decode("utf-16le", errors="ignore").replace("\ufeff", "")
for line in txt.splitlines():
    if any(k in line.lower() for k in ["login", "server", "account", "expert", "algo"]):
        print("  ", line)
