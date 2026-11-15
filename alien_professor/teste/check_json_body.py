#!/usr/bin/env python3
"""Reproduz JEsc + o body de AIAskOne (src/ai.mqh) e valida com json.loads."""
import json
import sys


def jesc(s: str) -> str:
    # espelha JEsc em src/ai.mqh (caracteres >=0x20, incl. acentos e emoji, passam direto)
    o = []
    for ch in s:
        c = ord(ch)
        if ch == "\\":
            o.append("\\\\")
        elif ch == '"':
            o.append('\\"')
        elif ch == "\n":
            o.append("\\n")
        elif ch == "\r":
            o.append("\\r")
        elif ch == "\t":
            o.append("\\t")
        elif c < 0x20:
            o.append("\\u%04x" % c)
        else:
            o.append(ch)
    return "".join(o)


def build_body(sys_txt: str, user: str, model: str, max_tok: int, temp: float = 0.2) -> str:
    return (
        '{"model":"' + jesc(model)
        + '","temperature":' + ('%.1f' % temp) + ',"max_tokens":' + str(max_tok)
        + ',"messages":[{"role":"system","content":"' + jesc(sys_txt)
        + '"},{"role":"user","content":"' + jesc(user) + '"}]}'
    )


def utf8_no_nul(body: str) -> bytes:
    raw = body.encode("utf-8")
    if raw.endswith(b"\x00"):
        raise AssertionError("UTF-8 body ends with NUL")
    return raw


def main() -> int:
    sys_txt = "Você é o professor.\nUse aspas \"assim\" e o caminho C:\\temp."
    user = (
        "Análise M1 do ouro: preço 3.878, tendência \"alta\".\n"
        "Atenção:\tFVG e BOS.\r\n"
        "Acentos: ação, não, você, coração.\n"
        "Emoji: 🚀📈 e controle \x01\x08\x0b\x1f no texto."
    )
    model = "grok-4.20-0309-non-reasoning"
    body = build_body(sys_txt, user, model, 220)
    raw = utf8_no_nul(body)
    data = json.loads(raw.decode("utf-8"))
    assert data["model"] == model
    assert data["messages"][0]["role"] == "system"
    assert data["messages"][1]["role"] == "user"
    assert data["messages"][0]["content"] == sys_txt
    assert data["messages"][1]["content"] == user
    assert "\x00" not in body
    assert b"\x00" not in raw
    # controles <0x20 (exceto os já cobertos por \n \r \t) saem como \\u00XX
    assert "\\u0001" in body and "\\u0008" in body and "\\u000b" in body and "\\u001f" in body
    assert data["temperature"] == 0.2
    body6 = build_body(sys_txt, user, model, 350, 0.6)
    data6 = json.loads(body6)
    assert data6["temperature"] == 0.6
    print("ok", len(raw), "bytes, json.loads ok, temp 0.2/0.6")
    return 0


if __name__ == "__main__":
    sys.exit(main())
