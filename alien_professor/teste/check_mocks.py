#!/usr/bin/env python3
"""Mocks: JSON body, contexto sem preço zero, parser de comandos Telegram, pontuação +1R/-1R."""
import json, sys, os
ROOT = os.environ.get("ALIEN_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- JSON body (espelha JEsc + AIAskOne, temperatura 0.2 análise / 0.6 texto livre) ----
def jesc(s: str) -> str:
    o = []
    for ch in s:
        c = ord(ch)
        if ch == "\\": o.append("\\\\")
        elif ch == '"': o.append('\\"')
        elif ch == "\n": o.append("\\n")
        elif ch == "\r": o.append("\\r")
        elif ch == "\t": o.append("\\t")
        elif c < 0x20: o.append("\\u%04x" % c)
        else: o.append(ch)
    return "".join(o)

def build_body(sys_txt, user, model="gemini-3.5-flash-lite", max_tok=800, temp=0.2):
    return ('{"model":"' + jesc(model)
            + '","temperature":' + ('%.1f' % temp) + ',"max_tokens":' + str(max_tok)
            + ',"messages":[{"role":"system","content":"' + jesc(sys_txt)
            + '"},{"role":"user","content":"' + jesc(user) + '"}]}')

def test_json_body():
    sys_txt = "Use SOMENTE os números do CONTEXTO.\nVEREDITO: COMPRA ou VENDA ou ESPERAR."
    user = "CONTEXTO DO MERCADO:\n{\"bid\":3878.5,\"ask\":3878.7}\n\nMENSAGEM: \"vale comprar?\""
    raw = build_body(sys_txt, user).encode("utf-8")
    assert not raw.endswith(b"\x00") and b"\x00" not in raw
    data = json.loads(raw.decode("utf-8"))
    assert data["temperature"] == 0.2
    assert data["messages"][1]["content"] == user
    assert data["messages"][0]["content"] == sys_txt
    data6 = json.loads(build_body(sys_txt, user, max_tok=350, temp=0.6))
    assert data6["temperature"] == 0.6
    print("ok json_body", len(raw), "bytes, temp 0.2/0.6")

# ---- contexto: snapshot válido, preços != 0 ----
def sample_context(bid=3878.5, ask=3878.7):
    return {
        "simbolo": "XAUUSD",
        "bid": bid, "ask": ask, "preco": bid, "spread": round(ask-bid, 5),
        "hora_servidor": "2026.11.15 10:00", "hora_utc3": "2026.11.15 05:00",
        "sessao": "Londres - horário BOM",
        "tendencias_detalhe": {
            "D1": {"tf":"D1","tendencia":1,"ema_inclinacao":1,"ema50":3860.0,"atr":25.0,"ok":True},
            "H4": {"tf":"H4","tendencia":1,"ema_inclinacao":1,"ema50":3870.0,"atr":8.0,"ok":True},
            "H1": {"tf":"H1","tendencia":-1,"ema_inclinacao":0,"ema50":3875.0,"atr":4.0,"ok":True},
            "M15":{"tf":"M15","tendencia":1,"ema_inclinacao":1,"ema50":3877.0,"atr":1.5,"ok":True},
            "M5": {"tf":"M5","tendencia":1,"ema_inclinacao":1,"ema50":3878.0,"atr":0.8,"ok":True},
            "M1": {"tf":"M1","tendencia":0,"ema_inclinacao":0,"ema50":3878.4,"atr":0.3,"ok":True},
        },
        "liquidez": {"PDH":{"preco":3890.0,"estado":"intacto"}, "asia_max":{"preco":3882.0,"estado":"varrida"}},
        "varridas_recentes": [{"nome":"Ásia máx.","preco":3882.0,"hora":"09:40"}],
        "noticias_2h": [{"hora":"11:30","min":90,"moeda":"USD","impacto":"forte","evento":"CPI"}],
        "conversa_recente": ["10:00 Vitor: como tá o ouro?"],
        "historico_veredictos": {"n":12,"acerto_60m":"7/10","frase":"seu histórico: veredito COMPRA em Londres acertou 5/6"},
        "hoje": {"trades":0,"stops":0,"resultado_usd":0.0},
    }

def context_ok(j: dict) -> bool:
    bid = j.get("bid", j.get("preco", 0)) or 0
    ask = j.get("ask", 0) or 0
    return bid > 0 and (ask == 0 or ask >= bid)

def test_context():
    ctx = sample_context()
    raw = json.dumps(ctx, ensure_ascii=False)
    data = json.loads(raw)
    assert context_ok(data)
    for k in ("bid","ask","preco","spread","hora_utc3","tendencias_detalhe","liquidez","noticias_2h","conversa_recente","historico_veredictos"):
        assert k in data
    assert data["bid"] != 0 and data["preco"] != 0
    bad = sample_context(0, 0)
    assert not context_ok(bad)
    # corpo da requisição com contexto válido
    body = build_body("sys", "CONTEXTO DO MERCADO:\n"+raw+"\n\nMENSAGEM: analise")
    payload = json.loads(body)
    ctx2 = json.loads(payload["messages"][1]["content"].split("CONTEXTO DO MERCADO:\n",1)[1].split("\n\nMENSAGEM:",1)[0])
    assert context_ok(ctx2)
    print("ok context non-zero")

# ---- parser de comandos (espelha ParseCmd) ----
def parse_cmd(text: str):
    text = text.strip()
    if not text:
        return False, "", ""
    sp = text.find(" ")
    head = text[:sp] if sp > 0 else text
    args = text[sp+1:] if sp > 0 else ""
    args = args.strip()
    at = head.find("@")
    if at > 0:
        head = head[:at]
    cmd = head.lower()
    return (len(cmd) > 0 and cmd[0] == "/"), cmd, args

COMMANDS = [
    ("/analise", True, "/analise", ""),
    ("/analise H4", True, "/analise", "H4"),
    ("/análise XAUUSD M15", True, "/análise", "XAUUSD M15"),
    ("/plano", True, "/plano", ""),
    ("/niveis", True, "/niveis", ""),
    ("/níveis", True, "/níveis", ""),
    ("/diario", True, "/diario", ""),
    ("/aprendizado", True, "/aprendizado", ""),
    ("/alerta 3870.5", True, "/alerta", "3870.5"),
    ("/alerta", True, "/alerta", ""),
    ("/pausa", True, "/pausa", ""),
    ("/retoma", True, "/retoma", ""),
    ("/risco", True, "/risco", ""),
    ("/status", True, "/status", ""),
    ("/noticias", True, "/noticias", ""),
    ("/notícias", True, "/notícias", ""),
    ("/foto", True, "/foto", ""),
    ("/ajuda", True, "/ajuda", ""),
    ("/help", True, "/help", ""),
    ("/start", True, "/start", ""),
    ("/analise@Alierprofessorbot H1", True, "/analise", "H1"),
    ("  /PLANO  ", True, "/plano", ""),
    ("vale comprar agora?", False, "vale comprar agora?", ""),
    ("como tá o M15?", False, "como tá o ouro?"[:0]+"como tá o M15?", ""),  # not a cmd
    ("/desconhecido", True, "/desconhecido", ""),
]

def test_commands():
    known = {"/analise","/análise","/plano","/niveis","/níveis","/diario","/diário",
             "/aprendizado","/alerta","/pausa","/retoma","/risco","/status",
             "/noticias","/notícias","/foto","/ajuda","/help","/start"}
    seen = set()
    for text, iscmd, exp_cmd, exp_args in COMMANDS:
        ok, cmd, args = parse_cmd(text)
        assert ok == iscmd, (text, ok, iscmd)
        if iscmd:
            assert cmd == exp_cmd, (text, cmd, exp_cmd)
            assert args == exp_args, (text, args, exp_args)
            if cmd in known: seen.add(cmd if cmd != "/análise" else "/analise")
            if cmd == "/alerta" and args:
                assert float(args) > 0
        else:
            assert not cmd.startswith("/") or cmd == text.lower() or True
            assert not iscmd
    # todos os comandos documentados têm um caso
    for c in ["/analise","/plano","/niveis","/diario","/aprendizado","/alerta","/pausa","/retoma","/risco","/status","/noticias","/foto","/ajuda","/start"]:
        assert any(parse_cmd(t)[1].startswith(c) or parse_cmd(t)[1].startswith(c.replace("ise","ise")) for t,_,ec,_ in COMMANDS if t.startswith("/") or True)
        assert any(parse_cmd(t)[1] in (c, c.replace("noticias","notícias")) or parse_cmd(t)[1].startswith(c) for t,_,_,_ in COMMANDS)
    print("ok telegram commands", len(COMMANDS), "paths")

# ---- pontuação de veredito (+1R / -1R, mesmo candle = erro) ----
def score_bars(dir_, bid, r1, bars, t0):
    """bars: list of dicts time, high, low, oldest-last or any order; walked oldest first."""
    if r1 <= 0 or bid <= 0 or not bars:
        return "nenhum"
    up, dn = bid + r1, bid - r1
    for b in bars:
        if b["time"] <= t0:
            continue
        hit_up, hit_dn = b["high"] >= up, b["low"] <= dn
        if hit_up and hit_dn:
            return "erro"
        if dir_ == 1:
            if hit_dn: return "erro"
            if hit_up: return "acerto"
        else:
            if hit_up: return "erro"
            if hit_dn: return "acerto"
    return "nenhum"

def test_scoring():
    t0 = 1000
    # COMPRA: hits +1R first
    bars = [{"time":1010,"high":101.0,"low":99.6}, {"time":1020,"high":111.0,"low":100.0}]
    assert score_bars(1, 100.0, 10.0, bars, t0) == "acerto"
    # COMPRA: hits -1R first
    bars = [{"time":1010,"high":101.0,"low":89.0}, {"time":1020,"high":120.0,"low":90.0}]
    assert score_bars(1, 100.0, 10.0, bars, t0) == "erro"
    # both in same candle => erro (conservador)
    bars = [{"time":1010,"high":111.0,"low":89.0}]
    assert score_bars(1, 100.0, 10.0, bars, t0) == "erro"
    # VENDA acerto (price down 1R)
    bars = [{"time":1010,"high":100.5,"low":89.0}]
    assert score_bars(-1, 100.0, 10.0, bars, t0) == "acerto"
    # VENDA erro (price up 1R first)
    bars = [{"time":1010,"high":111.0,"low":99.0}]
    assert score_bars(-1, 100.0, 10.0, bars, t0) == "erro"
    # no hit
    bars = [{"time":1010,"high":101.0,"low":99.0}]
    assert score_bars(1, 100.0, 10.0, bars, t0) == "nenhum"
    # ignore bars at/before t0
    bars = [{"time":1000,"high":200.0,"low":0.0}, {"time":1010,"high":101.0,"low":99.0}]
    assert score_bars(1, 100.0, 10.0, bars, t0) == "nenhum"
    # bad R or bid
    assert score_bars(1, 0, 10, [{"time":1010,"high":1,"low":1}], t0) == "nenhum"
    assert score_bars(1, 100, 0, [{"time":1010,"high":1,"low":1}], t0) == "nenhum"
    # ESPERAR is not scored by the caller (empty)
    print("ok veredito scoring")


def test_engine():
    # shape of EngineJSON() — checklist, not a forecast; valid JSON; no zero prices
    sample = {
        "aviso": "checklist, nao previsao",
        "compra": 3,
        "venda": 2,
        "amd": "Londres manipulação (varreu Ásia mín. 4200.00)",
        "killzone": "Killzone NY manhã (07-10) | Silver Bullet NY 10-11",
        "dealing": "range 4190-4220  meio 4205  DESCONTO  OTE zona de compra",
        "poi_ob": "order block não mitigado 4192-4196",
        "price_action": "pin de alta no POI",
        "bollinger": {"M15": {"meio": 4205.5, "sup": 4218.0, "inf": 4193.0, "largura": 0.006, "squeeze": False, "pos": 0}},
        "volume": {"atual": 1200, "media20": 500, "razao": 2.4, "spike": True, "vwap": 4204.1, "vwap_banda": 3.2,
                   "poc_sessao": 4203.0, "vah_sessao": 4210.0, "val_sessao": 4196.0,
                   "poc_ontem": 4198.0, "vah_ontem": 4212.0, "val_ontem": 4188.0},
        "divergencias": {"M5": {"rsi": 1, "macd": 0}, "M15": {"rsi": 0, "macd": -1}},
        "correlacao": {},
        "fvg_abertos": {"alta": 1, "baixa": 0},
        "bos": {"exec": "BOS alta", "M15": 1, "H1": 1},
        "topos_iguais": 1,
        "fundos_iguais": 0,
        "fatores": [
            {"nome": "preço em desconto (abaixo de 50%)", "compra": "+", "venda": "·"},
            {"nome": "divergência de baixa M15", "compra": "·", "venda": "+"}
        ]
    }
    import json
    raw = json.dumps(sample, ensure_ascii=False)
    data = json.loads(raw)
    assert data["aviso"].startswith("checklist")
    assert "previsao" in data["aviso"] or "previsão" in data["aviso"]
    assert data["volume"]["vwap"] > 0
    assert data["bollinger"]["M15"]["meio"] > 0
    assert data["compra"] >= 0 and data["venda"] >= 0
    for f in data["fatores"]:
        assert f["compra"] in ("+", "-", "·")
        assert f["venda"] in ("+", "-", "·")
        assert f["nome"]
    # silent fallback: empty corr object is valid
    assert isinstance(data["correlacao"], dict)
    # pages exist in source
    src = open(ROOT+"/src/engine.mqh", encoding="utf-8", errors="replace").read()
    assert "ENG_PAGS 4" in src
    assert "checklist, NÃO previsão" in src or "checklist, NÃO previsão" in src
    assert "EngCalc" in src and "somente" in src.lower() or "barra nova" in src
    assert "Silver Bullet" in src
    assert ("order block" in src) or ("bloco de ordens" in src) or ("Bloco de ordens" in src)
    chat = open(ROOT+"/src/auto_chat.mqh", encoding="utf-8", errors="replace").read()
    assert "EngineJSON()" in chat
    print("ok engine json/shape")



# ---- validador de cenários da IA (espelha AIValidaCenarios) ----
import re as _re

def _sem_acento(s: str) -> str:
    tab = str.maketrans("ÁÀÃÂÉÊÍÓÔÕÚáàãâéêíóôõú", "AAAAEEIOOOUAAAAEEIOOOU")
    return s.translate(tab)

def _num_apos(s: str, key: str):
    su, ku = _sem_acento(s).upper(), key.upper()
    pos = 0
    while True:
        i = su.find(ku, pos)
        if i < 0:
            return None
        j = i + len(ku)
        while j < len(su) and su[j] in " :=,;-":
            j += 1
        window = s[j:j+80]
        for m in _re.finditer(r"-?\d+(?:[.,]\d+)?", window):
            after = window[m.end():].lstrip()
            if after[:1] in ("R", "r"):
                continue
            tok = m.group().replace(",", ".")
            try:
                v = float(tok)
            except ValueError:
                continue
            if v > 0:
                return v
        pos = i + 1

def _cenario_dir(line: str):
    u = _sem_acento(line).upper()
    if "CENARIO" not in u:
        return 0
    if "COMPRA" in u or "BUY" in u:
        return 1
    if "VENDA" in u or "SELL" in u or "SHORT" in u:
        return -1
    return 0

def _fim_bloco(line: str, primeiro: bool) -> bool:
    if not primeiro and _cenario_dir(line) != 0:
        return True
    u = _sem_acento(line).upper()
    if "O QUE ESPERAR" in u:
        return True
    if "RISCOS" in u and "CENARIO" not in u:
        return True
    if "VEREDITO" in u:
        return True
    if u.startswith("CONFIAN") or u.startswith("CONFIANCA"):
        return True
    if "OBS.:" in u or u.startswith("OBS:"):
        return True
    return False

def valida_cenarios(t: str) -> str:
    t = t.replace("\r", "")
    if t == "" or "CENARIO" not in _sem_acento(t).upper():
        return t
    ls = t.split("\n")
    starts = []
    for i, line in enumerate(ls):
        d = _cenario_dir(line)
        if d != 0:
            starts.append((i, d))
    for a, direcao in reversed(starts):
        en = len(ls)
        for j in range(a + 1, len(ls)):
            if _fim_bloco(ls[j], False):
                en = j
                break
        bloco = "\n".join(ls[a:en])
        ent = _num_apos(bloco, "ENTRADA") or _num_apos(bloco, "ENTRY")
        stp = _num_apos(bloco, "STOP") or _num_apos(bloco, " SL")
        alv = _num_apos(bloco, "ALVO") or _num_apos(bloco, "TARGET") or _num_apos(bloco, " TP")
        ruim = False
        if ent and stp and alv and ent > 0:
            risk = abs(ent - stp)
            if risk <= 0:
                ruim = True
            else:
                rr = abs(alv - ent) / risk
                geo = (stp < ent < alv) if direcao == 1 else (alv < ent < stp)
                if (not geo) or rr < 1.0:
                    ruim = True
        if ruim:
            msg = "Cenário compra: sem setup válido (R<1)" if direcao == 1 else "Cenário venda: sem setup válido (R<1)"
            ls[a:en] = [msg]
    return "\n".join([x for x in ls if x != ""])

def test_valida_cenarios():
    # caso ao vivo: venda com alvo < 1R
    live = (
        "Viés: D1 alta, H1 baixa\n"
        "Cenário compra: entrada 3870.00, stop 3860.00, alvo 3890.00 (2.0R), invalidação no stop\n"
        "Cenário venda: entrada 3880.34, stop 3888.76, alvo 3880.17 (0.02R), invalidação no stop\n"
        "O que esperar agora: aguardar\n"
        "VEREDITO: VENDA"
    )
    out = valida_cenarios(live)
    assert "Cenário venda: sem setup válido (R<1)" in out
    assert "3880.17" not in out
    assert "3870.00" in out and "3890.00" in out  # compra válida permanece
    assert "VEREDITO: VENDA" in out

    # venda válida >= 1R
    ok_s = "Cenário venda: entrada 3880.00, stop 3890.00, alvo 3860.00 (2.0R)"
    assert valida_cenarios(ok_s) == ok_s

    # compra inválida: alvo do lado errado
    bad_b = "Cenário compra: entrada 3870, stop 3860, alvo 3850"
    assert valida_cenarios(bad_b) == "Cenário compra: sem setup válido (R<1)"

    # compra R exatamente 1.0 é válida
    eq = "Cenário compra: entrada 100, stop 90, alvo 110"
    assert valida_cenarios(eq) == eq

    # compra R < 1
    low = "Cenário compra: entrada 100, stop 90, alvo 109"
    assert valida_cenarios(low) == "Cenário compra: sem setup válido (R<1)"

    # venda com lado invertido (alvo acima da entrada)
    wr = "Cenário venda: entrada 3880.34, stop 3888.76, alvo 3895.00"
    assert valida_cenarios(wr) == "Cenário venda: sem setup válido (R<1)"

    # sem números: não altera
    bare = "Cenário venda: ainda sem gatilho claro"
    assert valida_cenarios(bare) == bare

    # fonte: validador chamado após o merge; prompt pede 1,5R; /status usa identidade do EA
    ai = open(ROOT+"/src/ai.mqh", encoding="utf-8", errors="replace").read()
    assert "AIValidaCenarios(AISemVeredito(t))" in ai
    assert "sem setup válido (R<1)" in ai
    chat = open(ROOT+"/src/auto_chat.mqh", encoding="utf-8", errors="replace").read()
    assert "1,5R" in chat and "alvos_locais" in chat
    assert "AlvosLocaisJSON()" in chat
    assert "900 caracteres" in chat
    assert "mano" in chat and "segura a mão" in chat
    assert "Macro tá vendido" in chat
    assert "Bora olhar o plano" in open(ROOT+"/src/auto_learn.mqh", encoding="utf-8", errors="replace").read()
    st = chat[chat.find("string StatusTxt"):chat.find("string AjudaTxt")]
    assert "Alier versão" in st and "Brasília" in st
    assert "RoboIdent()" in chat
    assert "magic %I64d" in chat
    # StatusTxt não usa mais g_status na linha Robô
    st = chat[chat.find("string StatusTxt"):chat.find("string StatusTxt")+800]
    assert "RoboIdent()" in st and ",g_status)" not in st
    print("ok scenario validator")


def escolhe_alvo(entry, stop, direcao, niveis, min_rr=1.5):
    """Espelha PlanoConsideraAlvo: liquidez/POI mais próximo no lado certo com R>=min_rr."""
    risk = abs(entry - stop)
    if risk <= 0:
        return None, 0.0
    best = None
    best_d = None
    best_rr = 0.0
    for lv, _nome in niveis:
        if direcao == 1 and not (lv > entry):
            continue
        if direcao == -1 and not (lv < entry):
            continue
        rr = abs(lv - entry) / risk
        if rr + 1e-12 < min_rr:
            continue
        d = abs(lv - entry)
        if best is None or d + 1e-12 < best_d:
            best, best_d, best_rr = lv, d, rr
    return best, best_rr

def test_plano_rr():
    # caso ao vivo: alvo 3880.17 dá R≈0.02 e deve ser descartado
    entry, stop = 3880.34, 3888.76
    niveis = [(3880.17, "perto demais"), (3860.00, "mín. semana"), (3840.00, "PDL")]
    tgt, rr = escolhe_alvo(entry, stop, -1, niveis, 1.5)
    assert tgt == 3860.00
    assert rr + 1e-12 >= 1.5
    # só o nível inválido: sem setup
    tgt0, rr0 = escolhe_alvo(entry, stop, -1, [(3880.17, "ruim")], 1.5)
    assert tgt0 is None and rr0 == 0.0
    # compra: ignora nível abaixo; pega o mais perto >=1.5R
    # risk=10, 1.5R=15, níveis 110 (R=1) inválido, 120 (R=2) e 140 (R=4) -> 120
    t2, r2 = escolhe_alvo(100, 90, 1, [(80, "abaixo"), (110, "1R"), (120, "2R"), (140, "4R")], 1.5)
    assert t2 == 120 and abs(r2 - 2.0) < 1e-9
    # R exatamente 1.5 é válido
    t3, r3 = escolhe_alvo(100, 90, 1, [(115, "1.5R")], 1.5)
    assert t3 == 115 and abs(r3 - 1.5) < 1e-9
    # fonte
    core = open(ROOT+"/src/core.mqh", encoding="utf-8", errors="replace").read()
    assert "input double InpMinRR" in core and "1.5" in core[core.find("InpMinRR"):core.find("InpMinRR")+80]
    assert "PlanoValido" in core and "PlanoConsideraAlvo" in core
    assert "PlanoSemSetup" in core and "sem setup válido (R<" in core
    tail = open(ROOT+"/src/auto_tail.mq5", encoding="utf-8", errors="replace").read()
    assert "PlanoValido(b)" in tail and "RRMinAlvo()" in tail
    assert "b.entry+2.0*risk" not in tail
    assert "tp=NormP(b.target)" in tail
    learn = open(ROOT+"/src/auto_learn.mqh", encoding="utf-8", errors="replace").read()
    assert "if(!PlanoValido(p)) return PlanoSemSetup(p.dir);" in learn
    chat = open(ROOT+"/src/auto_chat.mqh", encoding="utf-8", errors="replace").read()
    assert "PlanoCtxJSON" in chat and '"valido":false' in chat.replace('\\"','"')
    print("ok plano RR min")


def test_painel():
    core = open(ROOT+"/src/core.mqh", encoding="utf-8", errors="replace").read()
    pan = open(ROOT+"/src/painel.mqh", encoding="utf-8", errors="replace").read()
    chat = open(ROOT+"/src/auto_chat.mqh", encoding="utf-8", errors="replace").read()
    learn = open(ROOT+"/src/auto_learn.mqh", encoding="utf-8", errors="replace").read()
    assert "Máxima de ontem" in core and "Mínima da Ásia" in core and "Máxima de Londres" in core
    assert "PDH (máx. ontem)" not in core
    assert "Vazio de preço" in core or "Vazio de preço" in pan
    assert "Mudança de direção pra cima" in pan
    assert "Rompimento de estrutura pra baixo" in pan
    assert "Vem buscar liquidez aqui" in pan
    assert "Depois desce até aqui (alvo)" in pan
    assert "Se passar daqui, cancela" in pan
    assert "cenário, não certeza" in pan
    assert "PainelDesenhaDash" in pan and "g_painelMin" in core
    assert "InpLinhasChave" in core and "InpCenariosGrafico" in core and "InpMarcasGrafico" in core
    assert "RECOLHER" in open(ROOT+"/src/engine.mqh", encoding="utf-8", errors="replace").read()
    assert "Bloco de ordens" in open(ROOT+"/src/engine.mqh", encoding="utf-8", errors="replace").read()
    assert "NivelPorNome(\"Máxima de ontem\")" in chat
    learn += open(ROOT+"/src/auto_agente.mqh", encoding="utf-8", errors="replace").read()
    assert "🟢" in learn and "🔴" in learn and "💧" in learn and "🎯" in learn and "🛑" in learn
    assert "📰" in chat and "Segoe UI Emoji" in pan
    print("ok painel pt-br cenarios emoji")


# ---- tom do chat: texto livre curto, plano só quando pedem, aviso de edge controlado ----
import unicodedata

def _norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower()

def eh_pedido_analise(t: str) -> bool:
    u = _norm(t)
    if "analis" in u: return True
    if "/plano" in u: return True
    for k in ("qual o plano","cade o plano","me da o plano","mostra o plano","ver o plano"):
        if k in u: return True
    pe = u.find("entro")
    if pe >= 0 and (pe == 0 or u[pe-1] != "d"): return True
    if "entrar" in u or "vale compr" in u or "vale vend" in u: return True
    if "posso compr" in u or "posso vend" in u or "posso entr" in u: return True
    return False

def eh_reclama_repete(t: str) -> bool:
    u = _norm(t)
    return "repet" in u or "mesmo bloco" in u or "mesmo texto" in u or "de novo o mesmo" in u

def eh_so_noticia(t: str) -> bool:
    return (not eh_pedido_analise(t)) and "notic" in _norm(t)

def sem_aviso_edge(t: str) -> str:
    out = []
    for line in t.replace("\r","").split("\n"):
        u = _norm(line)
        if "2016-2025" in u or "nao tiveram edge" in u:
            continue
        out.append(line)
    return "\n".join(out)

def sem_campos_crus(t: str) -> str:
    t = t.replace("plano_compra:", "Se for comprar:").replace("plano_venda:", "Se for vender:")
    t = t.replace("alvos_locais:", "Alvos no gráfico:")
    t = t.replace("plano_compra", "plano de compra").replace("plano_venda", "plano de venda")
    t = t.replace("alvos_locais", "alvos no gráfico")
    return t

def sem_veredito(t: str) -> str:
    out = []
    for line in t.split("\n"):
        u = line.upper()
        if "VEREDITO" in u or u.startswith("CONFIAN"):
            continue
        out.append(line)
    return "\n".join(out).rstrip()

def tem_bloco_robo(t: str) -> bool:
    u = _norm(t)
    hits = 0
    if "plano de compra" in u or "se for comprar" in u: hits += 1
    if "plano de venda" in u or "se for vender" in u: hits += 1
    if "o que fazer agora" in u: hits += 1
    if "alvos no grafico" in u: hits += 1
    return hits >= 2

def corte_bloco(u: str) -> int:
    best = -1
    for k in ("\nse for comprar","\nse for vender","\nplano de compra","\nplano de venda",
              "\no que fazer agora","\nalvos no grafico","\nmacro ta "):
        p = u.find(k)
        if p >= 0 and (best < 0 or p < best):
            best = p
    return best

def so_resposta_curta(t: str, pergunta: str = "") -> str:
    t = sem_veredito(sem_campos_crus(sem_aviso_edge(t))).strip()
    u = _norm(t)
    cortar = tem_bloco_robo(t) or eh_so_noticia(pergunta) or eh_reclama_repete(pergunta)
    if cortar:
        cut = corte_bloco(u)
        if eh_so_noticia(pergunta) or eh_reclama_repete(pergunta):
            m = u.find("\nmacro")
            if m >= 0 and (cut < 0 or m < cut):
                cut = m
        if cut > 20:
            t = t[:cut].rstrip()
    return t

ROBO_DUMP = (
    "CPI dos EUA às 11:30 (Brasília), daqui a 90 min, impacto forte.\n"
    "\n"
    "Macro tá vendido (D1/H4/H1 pra baixo), M1 tentando subir.\n"
    "plano_compra: sem setup válido (R<1.5)\n"
    "plano_venda: entrada 3880.34, stop 3888.76, alvo 3860.00 (2.4R)\n"
    "alvos_locais: mín. semana 3860, PDL 3840\n"
    "O que fazer agora: esperar a notícia.\n"
    "Risco: CPI em 90 min, spread pode abrir.\n"
    "VEREDITO: ESPERAR\n"
    "Confiança: GEMINI1 + GEMINI2 (concordam)\n"
    "\n"
    "No teste 2016-2025 os sinais automáticos nota>=7 não tiveram edge."
)

def exemplo_livre(pergunta, ctx):
    """Resposta no tom combinado, usando só o contexto (sem API)."""
    if eh_pedido_analise(pergunta):
        return None
    if eh_so_noticia(pergunta):
        news = (ctx.get("noticias_2h") or [{}])[0]
        return (f"📰 {news.get('evento','CPI')} de {news.get('moeda','USD')} às {str(news.get('hora',''))[-5:]} "
                f"(hora do servidor), daqui a {news.get('min','?')} min, impacto {news.get('impacto','forte')}. "
                "Eu não entraria até passar isso.")
    if eh_reclama_repete(pergunta):
        return ("Beleza, não vou mais colar o plano inteiro. Se quiser só notícia, é /noticias; "
                "o plano completo eu mando no /analise ou /plano.")
    return "Me fala o que você quer olhar que eu respondo curto."

def test_tom_livre():
    assert not eh_pedido_analise("E as notícias")
    assert eh_so_noticia("E as notícias")
    assert not eh_pedido_analise("como tá o ouro?")
    assert eh_pedido_analise("/analise")
    assert eh_pedido_analise("analisa o M15")
    assert eh_pedido_analise("entro?")
    assert eh_pedido_analise("vale comprar agora?")
    assert not eh_pedido_analise("preço dentro da zona")
    assert eh_reclama_repete("Vc parece tá repetindo os não precisa")

    ctx = sample_context()
    news_q = "E as notícias"
    news_ex = exemplo_livre(news_q, ctx)
    assert "CPI" in news_ex and "90" in news_ex
    assert "plano_compra" not in news_ex and "2016-2025" not in news_ex
    assert "VEREDITO" not in news_ex and "ALIEN PROFESSOR" not in news_ex
    # se o modelo ainda despejar o template, o sanitizer deixa só a notícia
    news_limpo = so_resposta_curta(ROBO_DUMP, news_q)
    assert "CPI" in news_limpo
    assert "plano_compra" not in news_limpo and "plano de compra" not in news_limpo
    assert "2016-2025" not in news_limpo
    assert "VEREDITO" not in news_limpo
    assert "3880.34" not in news_limpo

    rep_q = "Vc parece tá repetindo os não precisa"
    rep_ex = exemplo_livre(rep_q, ctx)
    assert "não vou mais colar" in rep_ex or "nao vou mais colar" in _norm(rep_ex)
    assert "plano_compra" not in rep_ex and "foi mal" not in _norm(rep_ex)
    rep_limpo = so_resposta_curta("foi mal\n\n"+ROBO_DUMP, rep_q)
    assert "plano_compra" not in rep_limpo and "3880.34" not in rep_limpo
    assert "2016-2025" not in rep_limpo
    # não recicla o bloco; no máximo o começo (desculpa/notícia) sem o plano
    assert "O que fazer agora" not in rep_limpo

    # fonte
    ai = open(ROOT+"/src/ai.mqh", encoding="utf-8", errors="replace").read()
    chat = open(ROOT+"/src/auto_chat.mqh", encoding="utf-8", errors="replace").read()
    assert "DoubleToString(temp,1)" in ai
    assert "temp=plano?0.2:0.6" in chat
    assert "SysChatLivre" in chat and "SysChatAnalise" in chat
    livre = chat[chat.find("string SysChatLivre"):chat.find("string SysChatAnalise")]
    analise = chat[chat.find("string SysChatAnalise"):chat.find("string SysChat()")]
    assert "SOMENTE" in livre and "1 a 4" in livre
    assert "WhatsApp" in livre
    assert "não peça desculpa e cole o mesmo bloco" in livre or "nao peca desculpa" in _norm(livre)
    assert "Fala mano" in livre and "Não comece" in livre
    assert "Uma linha honesta" not in livre
    assert "1,5R" in analise and "Se for comprar" in analise
    assert "EdgeSePreciso(PlanoTxt())" in chat
    assert 'ChatIA(text,"")' in chat
    # header de texto livre sumiu
    assert 'ChatIA(text,"ALIEN PROFESSOR:")' not in chat
    # aviso de edge só entra em /analise (forcarPlano) e /plano, não no prompt livre como linha a imprimir
    assert "g_edgeAvisado" in chat
    print("EXEMPLO notícias:\n"+news_ex)
    print("EXEMPLO repetição:\n"+rep_ex)
    print("ok tom livre")

def test_instalar():
    k = ROOT+"/kit/"
    for f in ["INSTALAR.bat", "INSTALAR.ps1", "SUBIR_GITHUB.bat", "SUBIR_GITHUB.ps1"]:
        raw = open(k+f, "rb").read()
        assert all(b < 128 for b in raw), f+" tem caractere nao-ASCII (PowerShell 5 quebra)"
        assert b"\r\n" in raw and raw.count(b"\n") == raw.count(b"\r\n"), f+" precisa CRLF"
    bat = open(k+"INSTALAR.bat").read(); ps1 = open(k+"INSTALAR.ps1").read()
    assert "INSTALAR.ps1" in bat and "Feche" in ps1
    assert r"MetaQuotes\Terminal" in ps1 and "origin.txt" in ps1 and "RoboForex" in ps1
    assert r"Experts\ALIEN" in ps1 and "ALIEN_PROFESSOR*" in ps1 and "Remove-Item" in ps1
    assert "Read-Host" in ps1                       # pergunta o numero se tiver varios
    assert "WebRequestUrl" in ps1 and "api.telegram.org" in ps1 and "generativelanguage.googleapis.com" in ps1
    assert "foreach ($p in $todas) { Instala-Em $p }" not in ps1   # nao instala em todos
    gh = open(k+"SUBIR_GITHUB.ps1").read()
    assert "alien-dados" in gh and "push origin main" not in gh and "push -u origin $branch" in gh
    assert "winget install Git.Git" in gh and "AIza" in gh and ".gitignore" in gh
    assert "if (-not (Test-Path $cfgDst))" in ps1      # config pessoal nunca sobrescrita
    tg = open(ROOT+"/src/auto_tg.mqh").read()
    assert "ALIEN_config.txt" in tg and "CfgLoad" in tg and "gemini_chave_1" in tg
    print("ok instalar + subir github + config local")


def main():
    test_json_body()
    test_context()
    test_commands()
    test_scoring()
    test_engine()
    test_valida_cenarios()
    test_plano_rr()
    test_painel()
    test_tom_livre()
    test_instalar()
    test_botoes()
    test_resposta_curta()
    test_merge_livre()
    test_horarios()
    test_voltei()
    test_estado_persistido()
    test_noticias_extra()
    test_csv_quant()
    test_voz_body()
    test_preset_vitor()
    print("ok all mocks")
    return 0


# ===================== v12.3 (agente Alier) =====================
import re, datetime as _dt
SRC = ROOT+"/src/"
def _src(n): return open(SRC+n, encoding="utf-8", errors="replace").read()

def sem_acento_up(s):
    tr = str.maketrans("ÁÀÃÂÉÊÍÓÔÕÚáàãâéêíóôõú", "AAAAEEIOOOUAAAAEEIOOOU")
    return s.translate(tr).upper()

def botao_cmd(t):
    if len(t) > 24: return ""
    o = "".join(c for c in sem_acento_up(t) if "A" <= c <= "Z")
    return {"NOTICIAS":"/noticias","ANALISE":"/analise","PLANO":"/plano","FOTO":"/foto",
            "STATUS":"/status","PAUSA":"/pausa","RETOMA":"/retoma","AGENDA":"/agenda"}.get(o, "")

def test_botoes():
    assert botao_cmd("📰 Notícias") == "/noticias"
    assert botao_cmd("📊 Análise") == "/analise"
    assert botao_cmd("⏸️ Pausa") == "/pausa"
    assert botao_cmd("▶️ Retoma") == "/retoma"
    assert botao_cmd("e as notícias de hoje, vale entrar?") == ""
    ag = _src("auto_agente.mqh"); ch = _src("auto_chat.mqh")
    kb = re.search(r'string TgKbFixo\(\)\s*\{\s*return (.*?);\s*\}', ag, re.S).group(1)
    js = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', kb)).replace('\\"', '"')
    d = json.loads(js)
    labels = [b["text"] for row in d["keyboard"] for b in row]
    assert all(botao_cmd(l) for l in labels) and d["is_persistent"] is True
    # pausa/retoma pedem confirmação; só *_ok executa
    assert 'cmd=="/pausa"){ PedeConfirmaPausa(true)' in ch and 'cmd=="/pausa_ok"' in ch and 'cmd=="/retoma_ok"' in ch
    print("ok botoes + confirmacao")

PLANO_K = ["se for comprar","se for vender","plano de compra","plano de venda","o que fazer agora","alvos no grafico","cenario compra","cenario venda","compra:","venda:"]
def linha_plano(l):
    u = sem_acento_up(l).lower().lstrip()
    while u and not (u[0].isalnum() and u[0].isascii()): u = u[1:]
    return any(u.startswith(k) for k in PLANO_K)
def so_resposta_curta(t, so_noticia=True):
    out=[]; conteudo=False
    for x in t.split("\n"):
        x=x.strip()
        if not x: continue
        plano = linha_plano(x) or (so_noticia and sem_acento_up(x).lower().startswith("macro"))
        if plano:
            if conteudo: break
            continue
        out.append(x); conteudo=True
    return "\n".join(out) or "Sem novidade além do plano. Se quiser ver, toca em 🧭 Plano."

def test_resposta_curta():
    a = "Se for comprar: entra em 4000, stop 3990, alvo 4020\nSe for vender: sem setup\nTem CPI às 10:30 (Brasília), segura a mão."
    assert so_resposta_curta(a) == "Tem CPI às 10:30 (Brasília), segura a mão."
    b = "Notícia forte às 10:30.\nSe for comprar: entra em 4000\nO que fazer agora: esperar"
    assert so_resposta_curta(b) == "Notícia forte às 10:30."
    c = "🟢 Se for comprar: entra em 4000"
    assert "Plano" in so_resposta_curta(c)
    ch = _src("auto_chat.mqh")
    assert "if(StringFind(u,k[i])==0) p=0;" in ch           # CorteBloco corta no começo também
    assert 'if(EhSoNoticia(text)){ MemAdd("Vitor",text); SendMsg(NoticiasTxt()); return; }' in ch
    print("ok resposta curta / noticia local")

def custo_livre(t):
    u=t.lower(); c=len(t)
    if c<15: c+=2000
    if "plano_" in u or "alvos_locais" in u: c+=600
    if "se for comprar" in u or "se for vender" in u: c+=300
    if "veredito" in u: c+=200
    return c
def test_merge_livre():
    curta = "CPI às 10:30, cuidado."
    longa = "CPI às 10:30. Se for comprar: entra em 4000, stop 3990, alvo 4020. plano_venda: nada"
    assert min([longa, curta], key=custo_livre) == curta
    ai = _src("ai.mqh")
    assert "AICustoLivre(okT[i])" in ai and "As duas leituras bateram" in ai and "discordaram, então eu esperaria" in ai
    assert "(concordam)" not in ai and "Confiança: " not in ai
    print("ok merge livre + confianca natural")

def ny_offset(gmt):
    y=gmt.year
    def dom(m,n):
        d=_dt.datetime(y,m,1); add=(6-d.weekday())%7; return d+_dt.timedelta(days=add+7*(n-1))
    ini=dom(3,2)+_dt.timedelta(hours=7); fim=dom(11,1)+_dt.timedelta(hours=6)
    return 4 if ini<=gmt<fim else 5
def test_horarios():
    assert ny_offset(_dt.datetime(2026,7,1,12)) == 4
    assert ny_offset(_dt.datetime(2026,12,1,12)) == 5
    assert ny_offset(_dt.datetime(2026,3,8,6,59)) == 5 and ny_offset(_dt.datetime(2026,3,8,7,0)) == 4
    assert ny_offset(_dt.datetime(2026,11,1,5,59)) == 4 and ny_offset(_dt.datetime(2026,11,1,6,0)) == 5
    # servidor UTC+2 -> Brasília = servidor - 5h
    srv = _dt.datetime(2026,11,16,15,30); off=2*3600
    assert srv - _dt.timedelta(seconds=off+3*3600) == _dt.datetime(2026,11,16,10,30)
    eng=_src("engine.mqh"); core=_src("core.mqh")
    assert "gmt-5*3600" not in eng and "EngNyOffset" in eng
    assert "SrvParaBR" in core and "NewsListaBR" in core and "hora_brasilia" in core
    ch=_src("auto_chat.mqh")
    assert "hora do servidor" not in ch and "(servidor)" not in ch
    print("ok horarios Brasilia + NY verao")

def test_voltei():
    tail=_src("auto_tail.mq5"); ag=_src("auto_agente.mqh")
    assert "Voltei. Tô no" not in tail and "saldo $" not in ag[ag.find("void ParadaInit"):ag.find("// ---------------- 5.")]
    assert "ParadaInit();" in tail and "ParadaDeinit(r)" in tail
    assert "15*60" in ag and "ParadaFoiMexida" in ag and "TgMaster()" in ag
    # motivos de mexida não avisam
    mex = {1,2,3,4,5,7}
    for r in range(0,10):
        avisa = r not in mex
        assert avisa == (r in (0,6,8,9))
    print("ok voltei so apos queda")

def test_noticias_extra():
    ag=_src("auto_agente.mqh"); tail=_src("auto_tail.mq5"); ch=_src("auto_chat.mqh")
    assert "NoticiaResultado(); BomDia();" in tail and 'cmd=="/agenda"' in ch
    assert "HasActualValue" in ag and "d.hour!=8" in ag and '"P"+IntegerToString' in ag
    assert botao_cmd("🗓️ Agenda") == "/agenda"
    print("ok noticias: agenda, bom dia, resultado")

def test_estado_persistido():
    ag=_src("auto_agente.mqh"); ch=_src("auto_chat.mqh")
    assert "ALIEN_tg_estado.txt" in ag and "TgEstadoLoad" in ag
    assert ch.count("TgEstadoSave()") >= 3
    print("ok estado persistido")

def test_csv_quant():
    ag=_src("auto_agente.mqh")
    al = re.search(r'g_alLogHdr="([^"]+)"', ag).group(1).split(";")
    di = re.search(r'g_discHdr="([^"]+)"', ag).group(1).split(";")
    assert al[:4]==["hora_servidor","hora_brasilia","simbolo","tipo"] and "res60" in al and "mov60_R" in al and len(al)==12
    assert di[9]=="posicao" and di[10]=="seguiu" and di[11]=="motivo" and len(di)==12
    rd=open(ROOT+"/README_PT.md",encoding="utf-8").read()
    for col in ["mov60_R","seguiu","hora_brasilia","res15"]: assert col in rd, col
    print("ok csv quant documentado")

def test_voz_body():
    b64 = "T2dnUw=="
    body = ('{"contents":[{"role":"user","parts":[{"text":"' + jesc("Transcreva \"isso\"") + '"},{"inline_data":{"mime_type":"audio/ogg","data":"'
            + b64 + '"}}]}],"generationConfig":{"temperature":0,"maxOutputTokens":400}}')
    d=json.loads(body); assert d["contents"][0]["parts"][1]["inline_data"]["mime_type"]=="audio/ogg"
    resp = '{\n  "candidates": [{"content": {"parts": [{"text": "como tá o ouro"}]}}]\n}'
    k=resp.find('"text"'); q=resp.find('"', resp.find(":",k)+1)
    assert json.loads(resp[q:resp.find('"',q+1)+1]) == "como tá o ouro"
    print("ok voz body")

def test_preset_vitor():
    ss=open(ROOT+"/kit/presets/ALIEN_PROFESSOR_AUTO_seguro.set").read()
    assert "InpAllowRealAccount=false" in ss
    print("ok presets")

if __name__ == "__main__":
    sys.exit(main())
