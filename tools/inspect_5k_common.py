import os

ini_path = r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\config\common.ini"
raw = open(ini_path, "rb").read()
txt = raw.decode("utf-16", errors="ignore")
print(txt)
