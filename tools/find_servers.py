import re

raw = open(r"C:\Users\notebook\AppData\Roaming\MetaQuotes\Terminal\6A8B44BF3BA3300BEB24FFF647C54564\config\servers.dat", "rb").read()
# Find printable strings of length >= 4
strings = set()
for m in re.finditer(rb'[\x20-\x7E]{4,}', raw):
    strings.add(m.group(0).decode('ascii'))
# Also utf-16le strings
for m in re.finditer(rb'(?:[\x20-\x7E]\x00){4,}', raw):
    strings.add(m.group(0).decode('utf-16le'))

for s in sorted(strings):
    if any(k in s.lower() for k in ["goat", "server", "demo", "real"]):
        print(" ", s)
