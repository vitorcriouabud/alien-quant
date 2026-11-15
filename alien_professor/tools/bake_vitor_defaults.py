#!/usr/bin/env python3
"""Aplica os valores de um preset .set como defaults dos input() em um .mq5.
Nunca imprime valores de token/chave/chat. Usado só no build pessoal, fora do git.
"""
import argparse, re, os, sys

SECRET = ("InpTelegramToken", "InpTelegramChatId", "InpAIKey", "InpAI2Key", "InpGeminiKey2")

def load_set(path):
    vals = {}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            vals[k.strip()] = v
    return vals

def is_string_default(old: str) -> bool:
    o = old.strip()
    return o.startswith('"')

def mql_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')

def patch(src: str, vals: dict, report: list) -> str:
    # input TYPE Name = DEFAULT; // comment
    pat = re.compile(
        r'^(input\s+\S+\s+)(Inp\w+)(\s*=\s*)([^;]+)(;.*)$',
        re.M,
    )
    def repl(m):
        typ_and = m.group(1)
        name = m.group(2)
        mid = m.group(3)
        old = m.group(4)
        tail = m.group(5)
        if name not in vals:
            return m.group(0)
        raw = vals[name]
        if is_string_default(old):
            newval = '"' + mql_escape(raw) + '"'
        else:
            newval = raw
        if old.strip() == newval.strip() or old.strip() == '"' + raw + '"':
            report.append((name, "igual", len(raw)))
            return m.group(0)
        report.append((name, "trocado", len(raw)))
        return typ_and + name + mid + newval + tail
    return pat.sub(repl, src)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", required=True)
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    vals = load_set(args.set)
    src = open(args.src, "r", encoding="utf-8", errors="replace").read()
    # drop BOM if present
    if src.startswith("\ufeff"):
        src = src[1:]
    report = []
    out = patch(src, vals, report)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    # write UTF-8 with BOM for MetaEditor
    open(args.out, "w", encoding="utf-8-sig", newline="\n").write(out)
    os.chmod(args.out, 0o600)
    for name, st, n in report:
        tag = "secreto" if name in SECRET else "ok"
        print(f"  {name}: {st} len={n} ({tag})")
    missing = [k for k in vals if k.startswith("Inp") and k not in {r[0] for r in report} and not any(k==r[0] for r in report)]
    # fields in set not found in this mq5 are expected (AUTO vs TELEGRAM)
    nsec = sum(1 for name,st,_ in report if name in SECRET and st=="trocado")
    print(f"ok bake {os.path.basename(args.out)} campos={len(report)} secretos_trocados={nsec}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
