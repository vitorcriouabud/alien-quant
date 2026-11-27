"""Projeção operacional da Central e vigilância do supervisor existente no Dell."""
import argparse
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path
import json
import os
import re
import sqlite3
import subprocess
import time
from uuid import uuid4

UTC = timezone.utc
TASK = "ALIEN Autonomous Lab Supervisor"
VALID = re.compile(r"[A-Za-z0-9_-]{1,85}")
STATUS = {"queued": "na fila", "processing": "em execução", "publishing": "publicando",
          "completed": "concluída", "failed": "falhou"}
ACTIONS = {"quant_backtest": "backtest", "agent_review": "revisão", "diagnose": "diagnóstico",
           "peer_exchange": "comunicação", "collect": "coleta", "summarize": "resumo",
           "analyze_existing_report": "análise"}
ARTIFACT = "i3_20261127T000718Z"


def read(path):
    try:
        if path.stat().st_size > 1024 * 1024:
            return {}
        value = json.loads(path.read_bytes())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, RecursionError):
        return {}


def when(value):
    try:
        result = datetime.fromisoformat(value)
        return result.astimezone(UTC) if result.tzinfo else None
    except (TypeError, ValueError):
        return None


def show_time(value):
    return value.strftime("%d/%m/%Y %H:%M:%S UTC") if value else "indisponível"


def write(path, text):
    tmp = path.with_name(f".alien-{uuid4().hex}.tmp")
    try:
        tmp.write_text(text, encoding="utf-8", newline="\n")
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)


def process(args, timeout=9, env=None):
    try:
        return subprocess.run(args, encoding="utf-8", errors="replace", capture_output=True,
                              timeout=timeout, check=True, creationflags=subprocess.CREATE_NO_WINDOW,
                              env=env).stdout
    except (OSError, subprocess.SubprocessError):
        return None


def powershell(code, timeout=25, env=None):
    binary = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    return process([str(binary), "-NoProfile", "-NonInteractive", "-Command",
                    "$ErrorActionPreference='Stop';[Console]::OutputEncoding=[Text.UTF8Encoding]::new();" + code],
                   timeout, env)


def clock_reference(state, now):
    cached = state / "referencia_relogio.json"
    value = read(cached)
    last = when(value.get("utc_local"))
    old_offset = value.get("offset_s")
    if last and 0 <= (now - last).total_seconds() < 900 and type(old_offset) in (int, float):
        return old_offset
    log = process(["w32tm.exe", "/stripchart", "/computer:time.windows.com", "/samples:2", "/dataonly"], 11)
    offsets = [float(x.replace(",", ".")) for x in re.findall(r"([+-]\d+[.,]\d+)s\s*$", log or "", re.M)]
    if len(offsets) != 2 or abs(offsets[0] - offsets[1]) > 2:
        return None
    result = round(sum(offsets) / 2, 3)
    write(cached, json.dumps({"offset_s": result, "utc_local": now.isoformat()}))
    return result


def db_connect(state, readonly=True):
    path = state / "alien.db"
    mode = "ro" if readonly else "rw"
    return sqlite3.connect(f"{path.as_uri()}?mode={mode}", uri=True, timeout=3)


def active_db(state):
    try:
        with closing(db_connect(state)) as db:
            return db.execute("SELECT input_id, action, status FROM tasks WHERE status IN "
                              "('queued','processing','publishing') ORDER BY created_utc LIMIT 25").fetchall()
    except sqlite3.Error:
        return None


def recover(central, state, beat, now):
    expected = str(central / "MT5_DELL")
    env = {**os.environ, "ALIEN_HEALTH_ROOT": expected, "ALIEN_HEALTH_STATE": str(state)}
    get = (
        "$t=Get-ScheduledTask -TaskName 'ALIEN Autonomous Lab Supervisor' -TaskPath '\\';"
        "$a=@($t.Actions);"
        "if($a.Count -ne 1 -or $a[0].Arguments.IndexOf($env:ALIEN_HEALTH_ROOT,[StringComparison]::OrdinalIgnoreCase) -lt 0 "
        "-or $a[0].Arguments.IndexOf($env:ALIEN_HEALTH_STATE,[StringComparison]::OrdinalIgnoreCase) -lt 0 "
        "-or $a[0].Arguments -notlike '*supervisor.py*--continuous*'){throw 'Ação fora do escopo'};"
    )
    mode = powershell(get + "$t.State.ToString()", env=env)
    if mode is None:
        return "Agendador indisponível"
    mode = mode.strip()
    start = ["schtasks.exe", "/Run", "/TN", "\\" + TASK]
    if mode == "Ready":
        return ("Início solicitado ao Agendador" if process(start, timeout=18) is not None else
                "Início recusado pelo Agendador")
    stamp = when(beat.get("utc"))
    if mode != "Running" or not stamp or (now - stamp).total_seconds() <= 480:
        return "Supervisão normal" if mode == "Running" else "Aguardando o Agendador"
    mark = state / "heartbeat_em_verificacao.json"
    previous = read(mark)
    uptime = time.monotonic()
    old_uptime = previous.get("uptime")
    if (previous.get("utc") != beat.get("utc") or previous.get("pid") != beat.get("pid")
            or type(old_uptime) not in (int, float) or not 240 <= uptime - old_uptime <= 900):
        write(mark, json.dumps({"utc": beat.get("utc"), "pid": beat.get("pid"), "uptime": uptime}))
        return "Heartbeat atrasado. Aguardando segunda medi??o"
    try:
        with closing(db_connect(state, False)) as db:
            db.execute("BEGIN IMMEDIATE")
            current = read(central / "MT5_DELL/ESTADO/heartbeat.json")
            if current.get("utc") != beat.get("utc"):
                return "Heartbeat voltou a avançar"
            if db.execute("SELECT count(*) FROM tasks WHERE status IN ('processing','publishing')").fetchone()[0]:
                return "Heartbeat atrasado. Trabalho ativo preservado"
            pid = current.get("pid")
            if type(pid) is not int or pid <= 0:
                return "Heartbeat atrasado. Processo não confirmado"
            env["ALIEN_HEALTH_PID"] = str(pid)
            stop = (
                "$p=Get-CimInstance Win32_Process -Filter ('ProcessId='+$env:ALIEN_HEALTH_PID);"
                "if(!$p -or !$p.CommandLine -or $p.CommandLine.IndexOf($env:ALIEN_HEALTH_STATE,[StringComparison]::OrdinalIgnoreCase) -lt 0 "
                "-or $p.CommandLine -notlike '*supervisor.py*--continuous*'){throw 'Processo não confirmado'};"
                "'OK'"
            )
            verified = powershell(get + stop, timeout=30, env=env)
            stopped = bool(verified and process(["schtasks.exe", "/End", "/TN", "\\" + TASK], timeout=18) is not None)
            db.rollback()
    except sqlite3.Error:
        return "Heartbeat atrasado. SQLite ocupado ou indisponível"
    if not stopped:
        return "Heartbeat atrasado. Parada recusada ou inconclusiva"
    return ("Supervisor reiniciado pelo monitor" if process(start, timeout=18) is not None else
            "Parada confirmada. Aguardando novo ciclo de início")


def temperature():
    raw = powershell(
        "$a=@(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature "
        "-OperationTimeoutSec 3 | ForEach-Object {$_.CurrentTemperature});"
        "ConvertTo-Json -Compress -InputObject $a", timeout=6)
    try:
        data = json.loads(raw)
        return [round(t / 10 - 273.15, 1) for t in data if type(t) is int and 2630 <= t <= 3980]
    except (TypeError, ValueError):
        return []


def state_of(beat, now):
    ago = now - when(beat.get("utc")) if now and when(beat.get("utc")) else None
    interval = beat.get("poll_interval_seconds")
    if ago is None or type(interval) is not int:
        return "sem confirmação"
    seconds = round(ago.total_seconds())
    if seconds < -30:
        return "horário divergente"
    return "disponível" if seconds <= max(3 * interval, 240) else "heartbeat atrasado"


def results(root):
    out = {}
    for file in (root / "RESULTADOS").glob("task_*/RESULTADO.json"):
        body = read(file)
        task = body.get("input_id")
        stamp = when(body.get("completed_utc"))
        if (isinstance(task, str) and VALID.fullmatch(task) and file.parent.name == "task_" + task
                and body.get("schema") == "alien.result/v1" and body.get("lab_mode") == "DEMO"
                and body.get("status") in ("completed", "failed") and stamp
                and isinstance(body.get("action"), str)):
            out[task.casefold()] = (stamp, task, body)
    return out


def pending(root, receipts, rows):
    current = {x[0].casefold(): (x[0], x[1], STATUS[x[2]]) for x in rows or ()
               if isinstance(x[0], str) and VALID.fullmatch(x[0])}
    root = root / "ENTRADA/pendentes"
    for path in root.glob("*.json"):
        key = path.stem.casefold()
        if key in receipts or key in current or not VALID.fullmatch(path.stem):
            continue
        body = read(path)
        if (body.get("schema") == "alien.task/v1" and body.get("id") == path.stem
                and isinstance(body.get("action"), str)):
            current[key] = (path.stem, body.get("action"), "aguardando recibo")
    return list(current.values())


def quotas(central):
    q = read(central / "MT5_DELL/ESTADO/COTAS_CODEX.json")
    i3 = read(central / "ESTADO/PESQUISADOR_I3.json").get("limits", {})
    view = []
    for agent, label in (("codex-pessoal", "Codex pessoal"), ("codex-business", "Codex Business")):
        windows = []
        for slot in q.get(agent, {}).get("janelas", []):
            unit, percent = slot.get("janela_min"), slot.get("restante_pct")
            if type(unit) is int and type(percent) in {int, float} and 0 <= percent <= 100:
                windows.append(f"{percent:g}% ({unit} min)")
        view.append(f"| {label} | {' · '.join(windows) or 'indisponível'} | {show_time(when(q.get('consulta_utc')))} |")
    remaining, total = i3.get("credits_remaining"), i3.get("credits_allowance")
    reported = f"{remaining:,} de {total:,} créditos".replace(",", ".") if type(remaining) is int and type(total) is int else "indisponível"
    view.append(f"| Abacus | {reported} | {show_time(when(i3.get('credits_as_of_utc')))} |")
    view.append("| Antigravity | percentual indisponível | — |")
    return view


def build(central, state, now, offset, dell, i3, monitor, thermal):
    effective = now + timedelta(seconds=offset) if offset is not None else None
    temp = " / ".join(f"{t:.1f} °C".replace(".", ",") for t in thermal) if thermal else "indisponível"
    if thermal:
        temp += " (zonas térmicas ACPI)"
    i3module = read(central / "ESTADO/ESTADO_IA_LOCAL.json")
    route = "painel da rota publicado" if i3module.get("schema") == "alien.desk/v1" else "ativação pendente"
    received = (state / "transferencias" / ARTIFACT / "intelligence/science.db").is_file()
    receipt = read(central / "MT5_DELL/RESULTADOS/task_i3_dell_sqlite_20261126_01/RESULTADO.json")
    verified = received and receipt.get("status") == "completed"
    rows = [
        "# Painel ALIEN",
        "",
        "Pesquisa quantitativa de XAUUSD · simulação e DEMO · engenharia principal com Codex pessoal",
        "",
        f"Atualização pela referência NTP — {show_time(effective)}",
        f"Relógio local do Dell — {show_time(now)}",
        "Desvio medido: " + (f"{offset:+.1f} s para a referência NTP" if offset is not None else "indisponível"),
        "",
        "## Computadores",
        "",
        "| Máquina | Disponibilidade | Temperatura | Função |",
        "|---|---|---|---|",
        f"| Dell i7 | {state_of(dell, now)} | {temp} | Scheduler e executor MT5 |",
        f"| Samsung i3 | {state_of(i3, effective)} | indisponível | Agentes MT5 e Intelligence |",
        "",
        f"Recuperação do Dell — {monitor}.",
        f"Abacus automático — {route}.",
        "Snapshots SQLite reais — " + ("recebidos e verificados em armazenamento isolado." if verified else
                                        "aguardando recibo e validação no Dell."),
        "",
        "## Tarefas e progresso",
        "",
        "| Máquina | Tarefa | Ação | Etapa |",
        "|---|---|---|---|",
    ]
    recent = []
    for label, base, live in (("Dell", central / "MT5_DELL", active_db(state)), ("Samsung", central, None)):
        records = results(base)
        recent.extend((entry[0], label, entry[1], entry[2]) for entry in records.values())
        open_tasks = pending(base, records, live)
        for task, action, status in open_tasks[:15]:
            rows.append(f"| {label} | §{task}§ | {ACTIONS.get(action, 'outra')} | {status} |")
        if not open_tasks:
            rows.append(f"| {label} | — | — | sem pendências visíveis |")
        if len(open_tasks) > 15:
            rows.append(f"| {label} | — | — | {len(open_tasks) - 15} outras pendências |")
    rows.extend(["", "## Resultados recentes", "", "| Máquina | Tarefa | Ação | Estado |",
                 "|---|---|---|---|"])
    for _, label, task, body in sorted(recent, key=lambda x: x[:3], reverse=True)[:10]:
        rows.append(f"| {label} | §{task}§ | {ACTIONS.get(body.get('action'), 'outra')} | {STATUS[body['status']]} |")
    rows.extend(["", "## Cotas observadas", "", "| Agente | Franquia observada | Coleta UTC |",
                 "|---|---|---|", *quotas(central), "", "Os percentuais são fotografias da hora indicada.", "",
                 "## Continuidade", "", "Reserva científica — 25/11 a 09/12/2026, inclusive.", "",
                 "[Memória de retomada](https://drive.google.com/file/d/1VdXgru-4pF2A_9oIQcPmOaNHeC5aAits/view) · "
                 "[Protocolo](https://drive.google.com/file/d/1WjOviKwR65Rm8cp4a-Tv8X8HHhgpcsM9/view) · "
                 "[Resultados Dell](https://drive.google.com/drive/folders/1wCW30iilZ_TIpL6F3eR8hCiURMOUtb_V) · "
                 "[Resultados Samsung](https://drive.google.com/drive/folders/1kvL-oxEg5PD_GhYeIb-0zQxWE-4Fk7-M)", ""])
    return "\n".join(rows).replace("§", chr(96))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--central", type=Path, required=True)
    p.add_argument("--state", type=Path, required=True)
    p.add_argument("--painel-apenas", action="store_true")
    a = p.parse_args()
    central, state = a.central.resolve(), a.state.resolve()
    if state.is_relative_to(central) or not (state / "quant_executor.json").is_file():
        p.error("Estado existente do Dell indisponível.")
    if not (central / "MEMORIA_MESTRE_ALIEN.md").is_file():
        return
    now = datetime.now(UTC)
    dell = read(central / "MT5_DELL/ESTADO/heartbeat.json")
    i3 = read(central / "ESTADO/heartbeat.json")
    monitor = "apenas leitura" if a.painel_apenas else recover(central, state, dell, now)
    offset = clock_reference(state, now)
    thermal = temperature()
    write(central / "PAINEL_ALIEN.md", build(central, state, now, offset, dell, i3, monitor, thermal))
    write(state / "monitor_dell.json", json.dumps({"utc_local": now.isoformat(), "monitor": monitor,
                                                    "ntp_offset_s": offset, "temperatura_acpi_c": thermal},
                                                   ensure_ascii=False))


if __name__ == "__main__":
    main()
