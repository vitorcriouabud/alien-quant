"""Fila de pesquisa ALIEN para uma instalação portátil dedicada do MT5."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
from html import unescape
import json
from pathlib import Path
import re
from runpy import run_path
import shutil
import socket
import subprocess
import sys
import time
from uuid import uuid4
from zipfile import ZIP_DEFLATED, ZipFile
from xml.etree import ElementTree

REPO = Path(__file__).resolve().parents[1]
EA = REPO / "MQL5/Experts/ALIEN_V12_1_INSTITUTIONAL.mq5"
PRESET = REPO / "MQL5/Profiles/Tester/ALIEN_V12_1_INSTITUTIONAL.set"
MARKER = ".alien-tester-only"
REMOTE_SWEEP = "remote-spread-sweep"
SPREAD_VALUES = {20, 25, 30}
SPREAD_PARAMETER = "AbsoluteMaxSpreadPts"
NODES = ("192.168.3.47:2000", "192.168.3.47:2001")
GIT_TIMEOUT = 90
COMPILE_TIMEOUT = 600
TERMINAL_TIMEOUT = 6 * 3600
ATTEMPT_LIMIT = 2
RETRY_DELAY = 20
IDLE_LIMITS = {"initialization": 600, "history": 1200, "simulation": 1800}
POLL_SECONDS = 15
HISTORY_START = re.compile(
    r"preliminary downloading of history ticks started|"
    r"history (?:ticks )?(?:downloading|synchronization) started|"
    r"synchronizing (?:the )?(?:ticks|history)", re.I,
)
HISTORY_DONE = re.compile(
    r"preliminary downloading of history ticks completed|"
    r"history (?:ticks )?(?:downloading|synchronization) completed", re.I,
)
SIMULATION_START = re.compile(
    r"generating based on real ticks|\btesting of .+ started\b|"
    r"\b(?:complete |genetic )?optimization started\b|\btest(?:ing)? started\b", re.I,
)
TRANSIENT_HISTORY = re.compile(
    r"preliminary downloading of history ticks cancel[le]*d|"
    r"history[^\n]{0,60}(?:timed out|download failed)|"
    r"connection (?:failed|lost|timed out)|failed to connect", re.I,
)
FALLBACK = re.compile(
    r"no real ticks[^\n]*tick generation used|"
    r"real ticks begin from[^\n]*every tick generation used|"
    r"real ticks (?:discarded|missing) for [1-9][0-9]* minute|"
    r"real ticks unavailable[^\n]*generat", re.I,
)
REAL_TICKS = re.compile(
    r"real ticks begin from|real ticks synchronization completed|"
    r"generat(?:ing|ed) based on real ticks|using real ticks", re.I,
)
SAFE_JOURNAL_EVENT = re.compile(
    r"\b(?:preliminary downloading of history ticks (?:started|completed|cancel[le]*d)|"
    r"history (?:ticks )?synchronization (?:started|completed)|"
    r"no history data(?:, stop testing)?|no real ticks, every tick generation used|"
    r"real ticks (?:discarded|missing) for \d+ minutes?|"
    r"real ticks begin from \d{4}\.\d{2}\.\d{2}(?: \d{2}:\d{2}:\d{2})?(?:, every tick generation used)?|"
    r"generating based on real ticks|connection (?:failed|lost|timed out|closed)|"
    r"failed to connect|authorization failed|automatic testing finished|"
    r"test passed(?: in [\d:.]+)?|optimization finished(?:, total passes \d+)?|"
    r"local \d+ tasks \([\d.%]+\), remote \d+ tasks \([\d.%]+\), cloud \d+ tasks \([\d.%]+\))\b",
    re.I,
)


def save(path, value):
    tmp = path.with_name(f".{path.name}.{uuid4().hex}.tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def utc():
    return datetime.now(timezone.utc).isoformat()


def parse_job(data):
    keys = {"from", "to", "mode", "symbol", "model"}
    if not isinstance(data, dict) or set(data) != keys:
        raise ValueError("Campos esperados: from, to, mode, symbol, model")
    if data["mode"] not in ("local", "local-passes", "remote-passes", "mixed-passes", REMOTE_SWEEP):
        raise ValueError("Modo inválido")
    if not isinstance(data["symbol"], str) or not re.fullmatch(r"XAUUSD(?:[._-]?[A-Za-z0-9]{1,12})?", data["symbol"]):
        raise ValueError("Símbolo XAUUSD inválido")
    if type(data["model"]) is not int or data["model"] not in (1, 4):
        raise ValueError("Modelo deve ser 1 (OHLC M1) ou 4 (ticks reais)")
    dates = []
    for key in ("from", "to"):
        if not isinstance(data[key], str) or not re.fullmatch(r"\d{4}\.\d{2}\.\d{2}", data[key]):
            raise ValueError("Use datas AAAA.MM.DD")
        dates.append(datetime.strptime(data[key], "%Y.%m.%d").date())
    if not 0 < (dates[1] - dates[0]).days <= 93:
        raise ValueError("Intervalo permitido de 1 a 93 dias")
    if data["mode"] == REMOTE_SWEEP and (
        data["model"] != 1 or (dates[1] - dates[0]).days > 3
        or dates[1] >= datetime(2026, 11, 25).date()
    ):
        raise ValueError("Triagem de spread exige OHLC, até três dias e janela pré-reserva")
    return data


def tester_ini(job, name, parameters):
    mode = job["mode"]
    optimization = int(mode != "local")
    criterion = 0 if mode == REMOTE_SWEEP else 6
    return (
        "[Experts]\nEnabled=1\nAllowLiveTrading=0\nAllowDllImport=0\n\n"
        "[Tester]\n"
        f"Expert=ALIEN_Executor\\{name}.ex5\nExpertParameters={parameters}\n"
        f"Symbol={job['symbol']}\nPeriod=M1\nModel={job['model']}\n"
        f"FromDate={job['from']}\nToDate={job['to']}\n"
        f"Optimization={optimization}\nOptimizationCriterion={criterion}\n"
        "ForwardMode=0\nExecutionMode=0\nVisual=0\n"
        "Deposit=10000\nCurrency=USD\nLeverage=1:100\n"
        f"UseLocal={int(mode not in ('remote-passes', REMOTE_SWEEP))}\n"
        f"UseRemote={int(mode in ('remote-passes', 'mixed-passes', REMOTE_SWEEP))}\nUseCloud=0\n"
        f"Report=alien-executor-reports\\{name}\\report\nReplaceReport=0\nShutdownTerminal=1\n"
    )


def decode_log(data):
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16", errors="replace")
    if data[:100].count(0) > 25:
        return data.decode("utf-16-le", errors="replace")
    return data.decode("utf-8-sig", errors="replace")


def text_file(path):
    return decode_log(path.read_bytes())


@contextmanager
def locked(path):
    import msvcrt

    with path.open("a+b") as stream:
        stream.seek(0)
        msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            yield
        finally:
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)


def check_terminal(path):
    try:
        demo = load(path / MARKER)
    except (OSError, ValueError) as error:
        raise RuntimeError("Configure o arquivo local .alien-tester-only do MT5 portátil DEMO") from error
    if (not isinstance(demo, dict) or set(demo) != {"server", "login"}
            or not isinstance(demo["server"], str)
            or not re.fullmatch(r"[A-Za-z0-9.-]{1,80}", demo["server"])
            or type(demo["login"]) is not int or not 0 < demo["login"] < 2**63):
        raise ValueError("Identificação local DEMO inválida")
    for name in ("terminal64.exe", "metaeditor64.exe"):
        if not (path / name).is_file():
            raise RuntimeError(f"Executável ausente no MT5 portátil: {name}")
    return demo


def require_idle(path):
    command = (
        "Get-Process terminal64,metaeditor64 -ErrorAction SilentlyContinue "
        "| ForEach-Object { if ($_.Path) { $_.Path } else { '?' } }"
    )
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
        capture_output=True, text=True, timeout=60,
    )
    if result.stderr:
        raise RuntimeError("Não foi possível consultar os processos do MT5")
    executables = [item.strip() for item in result.stdout.splitlines() if item.strip()]
    if "?" in executables:
        raise RuntimeError("Não foi possível identificar o caminho de um processo do MT5.")
    if any(Path(item).resolve().parent == path for item in executables):
        raise RetryableRun("MT5 ou MetaEditor dedicado ainda aberto.")


def require_clean_source():
    paths = ["MQL5/Experts/" + EA.name, "MQL5/Profiles/Tester/" + PRESET.name]
    git = ["git", "--no-optional-locks", "-C", str(REPO)]
    revision = subprocess.check_output(git + ["rev-parse", "--verify", "HEAD"], text=True, timeout=GIT_TIMEOUT).strip()
    result = subprocess.run(
        git + ["diff", "--quiet", "--no-ext-diff", revision, "--"] + paths,
        capture_output=True, timeout=GIT_TIMEOUT,
    )
    if result.returncode == 1:
        raise RuntimeError("Fonte ou preset com alterações locais. Registre a revisão primeiro.")
    result.check_returncode()
    return revision


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def compile_ea(mt5, run, name, meta, probe=False):
    folder = mt5 / "MQL5/Experts/ALIEN_Executor"
    folder.mkdir(parents=True, exist_ok=True)
    source = folder / f"{name}.mq5"
    if probe:
        source.write_text(PROBE, encoding="ascii")
    else:
        shutil.copyfile(EA, source)
    log = run / "compile.log"
    command = [
        str(mt5 / "metaeditor64.exe"), "/portable",
        f"/compile:{source}", f"/log:{log}",
    ]
    result = subprocess.run(command, cwd=mt5, timeout=COMPILE_TIMEOUT)
    meta["metaeditor_exit"] = result.returncode
    binary = source.with_suffix(".ex5")
    if not log.is_file() or not binary.is_file() or not binary.stat().st_size:
        raise RuntimeError("Compilação sem log ou EX5 novo")
    if not re.search(r"(?:Result|Resultado)\s*:\s*0\s+(?:errors?|erros?)", text_file(log), re.I):
        raise RuntimeError("Compilação sem confirmação de zero erros")
    meta["sha256_ex5"] = digest(binary)


def prepare_preset(mt5, name, mode):
    directory = mt5 / "MQL5/Profiles/Tester"
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / f"{name}.set"
    if mode == "local":
        shutil.copyfile(PRESET, target)
    elif mode == REMOTE_SWEEP:
        raw = PRESET.read_bytes()
        encoding = "utf-8"
        if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
            encoding = "utf-16"
        elif raw.startswith(b"\xef\xbb\xbf"):
            encoding = "utf-8-sig"
        preset = raw.decode(encoding)
        preset = re.sub(r"\|\|Y(?=\r?$)", "||N", preset, flags=re.M)
        preset, count = re.subn(
            rf"(?m)^{SPREAD_PARAMETER}=[^\r\n]*",
            f"{SPREAD_PARAMETER}=25||20||5||30||Y",
            preset,
        )
        if count != 1:
            raise ValueError("Preset não tem exatamente um filtro de spread identificável")
        target.write_bytes(preset.encode(encoding))
    else:
        # Repete a estratégia com nove valores de um input de diagnóstico sem ordens.
        # O EA preserva todo o código do repositório para o backtest individual.
        target.write_text("Probe=0||0||1||8||Y\n", encoding="ascii")
    return target


def execute(mt5, run, meta):
    job = meta["task"]
    name = f"alien_{uuid4().hex}"
    meta["tester_run"] = name
    meta["stage"] = "process_check"
    require_idle(mt5)
    meta["stage"] = "git"
    meta["revision"] = require_clean_source()
    meta["stage"] = "compile"
    meta["sha256_source"] = digest(EA)
    meta["sha256_repository_preset"] = digest(PRESET)
    if job["mode"] in ("local", REMOTE_SWEEP):
        compile_ea(mt5, run, name, meta)
    else:
        compile_probe(mt5, run, name, meta)
    meta["stage"] = "config"
    preset = prepare_preset(mt5, name, job["mode"])
    meta["sha256_tester_preset"] = digest(preset)
    demo = check_terminal(mt5)
    common = f"[Common]\nServer={demo['server']}\nNewsEnable=0\n"
    settings = tester_ini(job, name, preset.name)
    (run / "tester.ini").write_text(common + "\n" + settings, encoding="ascii")
    private_settings = run / "terminal-start.ini"
    report_dir = mt5 / "alien-executor-reports" / name
    report_dir.mkdir(parents=True)
    meta["stage"] = "process_check"
    require_idle(mt5)
    tester_logs = mt5 / "Tester/logs"
    offsets = journal_offsets(tester_logs)
    meta["stage"] = "tester"
    try:
        private_settings.write_text(common + f"Login={demo['login']}\n\n" + settings, encoding="ascii")
        meta["terminal_exit"] = monitor_terminal(mt5, private_settings, demo["server"], job["symbol"], tester_logs, offsets, meta)
    finally:
        private_settings.unlink(missing_ok=True)
        collect_journal(tester_logs, offsets, run)
    meta["stage"] = "report"
    if meta.get("history_transient"):
        journal = "\n".join(text_file(path) for path in run.glob("journal-*.log"))
        if re.search(r"no history data|test(?:ing)? [^\n]*stop", journal, re.I):
            raise RetryableRun("Download ou conexão de histórico interrompido.")
    suffix = ".htm" if job["mode"] == "local" else ".xml"
    report = report_dir / ("report" + suffix)
    if meta["terminal_exit"] or not report.is_file() or not report.stat().st_size:
        raise RuntimeError("MT5 não produziu o relatório esperado com saída bem-sucedida")
    for path in report_dir.iterdir():
        if path.is_file() and path.suffix.lower() in {suffix, ".png", ".gif"}:
            shutil.copyfile(path, run / path.name)
    meta["sha256_report"] = digest(report)
    if job["mode"] == REMOTE_SWEEP:
        validate_sweep_report(report, run, meta)
    elif suffix == ".xml":
        validate_probe_report(report, meta)
    if suffix == ".htm":
        validate_backtest_report(run / report.name, job, name, meta)


class InvalidBacktestReport(ValueError):
    """O HTML existe, mas não comprova uma simulação válida."""


def validate_backtest_report(report, job, name, meta):
    parser = run_path(str(REPO / "tools/parse_and_record_results.py"))
    pairs = parser["parse_report_html"](parser["read_report_file"](str(report)))
    bars = parser["clean_number"](unescape(pairs.get("bars") or pairs.get("barras") or ""))
    ticks = parser["clean_number"](unescape(pairs.get("ticks") or ""))
    meta["bars"] = bars
    meta["ticks"] = ticks
    if bars <= 0 or ticks <= 0:
        raise InvalidBacktestReport("Relatório sem barras ou ticks históricos.")
    metrics = parser["extract_metrics"](pairs, report)
    date_range = metrics.get("period", "")
    if (metrics.get("symbol") != job["symbol"] or metrics.get("timeframe") != "M1"
            or job["from"] not in date_range or job["to"] not in date_range
            or not any(name in value for key, value in pairs.items() if key.startswith("expert"))):
        raise InvalidBacktestReport("Expert, símbolo ou intervalo divergente no relatório do MT5.")
    if not any(key in pairs for key in ("total trades", "total de negociacoes", "total de negocios")):
        raise InvalidBacktestReport("Relatório sem contagem de negociações.")
    meta["history_quality"] = unescape(pairs.get("history quality") or pairs.get("qualidade do historico") or "")
    if job.get("model") == 4:
        verify_real_ticks(report.parent, meta)
    metrics["report_file"] = report.name
    metrics["strategy"] = EA.stem
    metrics["exp_id"] = meta["id"]
    save(report.parent / "summary.json", metrics)


def verify_real_ticks(run, meta):
    journal = "\n".join(text_file(path) for path in sorted(run.glob("journal-*.log")))
    quality = re.search(r"(\d+(?:[.,]\d+)?)\s*%", meta.get("history_quality", ""))
    partial = quality and float(quality[1].replace(",", ".")) < 100
    fallback = partial or meta.get("tick_fallback_seen") or FALLBACK.search(journal)
    confirmed = meta.get("real_ticks_seen") or REAL_TICKS.search(journal)
    meta["real_ticks_confirmed"] = bool(confirmed and not fallback)
    if fallback:
        raise InvalidBacktestReport("O MT5 substituiu ticks reais por geração de ticks.")
    if not confirmed:
        raise InvalidBacktestReport("O diário do MT5 não confirma uso de ticks reais.")


class RetryableRun(RuntimeError):
    """Erro transitório conhecido, com orçamento limitado de retentativas."""


def journal_offsets(directory):
    return journal_offsets_for(directory, "*.log")


def read_journal_updates(directory, offsets):
    parts = []
    for name, size in journal_offsets(directory).items():
        offset = offsets.get(name, 0)
        offsets[name] = size
        if size < offset:
            offset = 0
        if size == offset:
            continue
        try:
            with (directory / name).open("rb") as stream:
                stream.seek(max(offset, size - 500_000))
                raw = stream.read(500_000)
            parts.append(decode_log(raw))
        except OSError:
            offsets[name] = offset
    return "\n".join(parts)


def history_sizes(mt5, server, symbol):
    state = {}
    for root in (mt5 / "bases", mt5 / "Tester/bases"):
        for directory, extension in (("ticks", "*.tkc"), ("history", "*.hcc")):
            path = root / server / directory / symbol
            for name, size in journal_offsets_for(path, extension).items():
                state[str(path / name)] = size
    return state


def journal_offsets_for(directory, pattern):
    sizes = {}
    for path in directory.glob(pattern):
        try:
            sizes[path.name] = path.stat().st_size
        except OSError:
            continue
    return sizes


def terminal_cpu(mt5, pid):
    query = (
        "Get-Process terminal64,metatester64 -ErrorAction SilentlyContinue "
        "| ForEach-Object { if ($_.Path -and $null -ne $_.CPU) "
        "{ '{0}|{1}|{2}' -f $_.Id,$_.CPU.ToString([Globalization.CultureInfo]::InvariantCulture),$_.Path } }"
    )
    try:
        sample = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", query],
            capture_output=True, text=True, timeout=15,
        )
    except (OSError, subprocess.SubprocessError):
        return {}
    result = {}
    for line in sample.stdout.splitlines():
        fields = line.split("|", 2)
        if len(fields) != 3 or not fields[0].isdigit():
            continue
        process_id, seconds, path = fields
        if int(process_id) == pid or Path(path).parent == mt5:
            try:
                result[process_id] = float(seconds)
            except ValueError:
                continue
    return result


def observe_journal(chunk, phase, meta):
    previous = phase
    progress = False
    for line in chunk.splitlines():
        if HISTORY_START.search(line):
            phase, progress = "history", True
        elif SIMULATION_START.search(line):
            phase, progress = "simulation", True
        elif HISTORY_DONE.search(line):
            if phase == "history":
                phase = "initialization"
            progress = True
        if phase != previous:
            meta["phase_changes"].append({"utc": utc(), "phase": phase})
            previous = phase
    meta["history_transient"] = bool(meta.get("history_transient") or TRANSIENT_HISTORY.search(chunk))
    meta["real_ticks_seen"] = bool(meta.get("real_ticks_seen") or REAL_TICKS.search(chunk))
    meta["tick_fallback_seen"] = bool(meta.get("tick_fallback_seen") or FALLBACK.search(chunk))
    return phase, progress


def terminal_deadline(phase, started, last_progress, now):
    if now - started >= TERMINAL_TIMEOUT:
        return "limite total do MT5"
    if now - last_progress >= IDLE_LIMITS[phase]:
        return {
            "initialization": "inicialização sem atividade observável",
            "history": "histórico sem crescimento ou eventos de progresso",
            "simulation": "simulação sem atividade observável",
        }[phase]
    return None


def monitor_terminal(mt5, config, server, symbol, tester_logs, offsets, meta):
    command = [str(mt5 / "terminal64.exe"), "/portable", f"/config:{config}"]
    cursors = offsets.copy()
    cached = history_sizes(mt5, server, symbol)
    phase = "initialization"
    started = last_progress = next_cpu = time.monotonic()
    cpu = {}
    meta["phase_changes"] = [{"utc": utc(), "phase": phase}]
    meta["history_growth_samples"] = meta["cpu_progress_samples"] = 0
    with subprocess.Popen(command, cwd=mt5) as process:
        try:
            while True:
                try:
                    code = process.wait(timeout=POLL_SECONDS)
                except subprocess.TimeoutExpired:
                    code = None
                chunk = read_journal_updates(tester_logs, cursors)
                phase, progress = observe_journal(chunk, phase, meta)
                now = time.monotonic()
                if code is not None:
                    return code
                sizes = history_sizes(mt5, server, symbol)
                if any(size > cached.get(path, 0) for path, size in sizes.items()):
                    meta["history_growth_samples"] += 1
                    progress = True
                    if phase == "initialization":
                        phase, _ = observe_journal("preliminary downloading of history ticks started", phase, meta)
                cached = sizes
                if phase == "simulation" and now >= next_cpu:
                    sample = terminal_cpu(mt5, process.pid)
                    if any(seconds - cpu.get(pid, seconds) >= 1 for pid, seconds in sample.items()):
                        meta["cpu_progress_samples"] += 1
                        progress = True
                    cpu = sample
                    next_cpu = now + 60
                if progress:
                    last_progress = now
                reason = terminal_deadline(phase, started, last_progress, now)
                if reason:
                    raise RetryableRun(reason)
        finally:
            meta["terminal_phase"] = phase
            meta["terminal_seconds"] = round(time.monotonic() - started, 2)
            if process.poll() is None:
                process.kill()
                process.wait(timeout=30)


def collect_journal(directory, offsets, run):
    for path in directory.glob("*.log"):
        try:
            with path.open("rb") as stream:
                size = stream.seek(0, 2)
                start = min(offsets.get(path.name, 0), size)
                if start == size:
                    continue
                stream.seek(max(start, size - 2_000_000))
                (run / ("journal-" + path.name)).write_bytes(stream.read(2_000_000))
        except OSError:
            continue


def optimization_values(report, column_name):
    tree = ElementTree.parse(report)
    namespace = {"s": "urn:schemas-microsoft-com:office:spreadsheet"}
    rows = tree.findall(".//s:Table/s:Row", namespace)
    for index, row in enumerate(rows):
        labels = [cell.text for cell in row.findall("s:Cell/s:Data", namespace)]
        if column_name in labels:
            column = labels.index(column_name)
            values = set()
            for item in rows[index + 1:]:
                cells = item.findall("s:Cell/s:Data", namespace)
                if len(cells) > column and cells[column].text is not None:
                    values.add(float(cells[column].text))
            return values
    return set()


def validate_probe_report(report, meta):
    values = optimization_values(report, "Probe")
    meta["probe_values"] = sorted(values)
    if values != set(range(9)):
        raise ValueError("XML não confirma os nove passes de diagnóstico")


def validate_sweep_report(report, run, meta):
    values = optimization_values(report, SPREAD_PARAMETER)
    meta["sweep_values"] = sorted(values)
    if values != SPREAD_VALUES:
        raise ValueError("XML não confirma os três limites de spread previstos")
    journal = "\n".join(text_file(path) for path in sorted(run.glob("journal-*.log")))
    if not re.search(r"local 0 tasks[^\n]+remote 3 tasks[^\n]+cloud 0 tasks", journal, re.I):
        raise ValueError("O diário não confirma que os três passes rodaram nos agentes remotos")
    meta["remote_passes_confirmed"] = 3
    meta["evidence_scope"] = "triagem_ohlc"


PROBE = """#property strict
input int Probe = 0;
int OnInit() { return MQLInfoInteger(MQL_TESTER) ? INIT_SUCCEEDED : INIT_FAILED; }
void OnTick() {}
double OnTester() { return (double)Probe; }
"""


def compile_probe(mt5, run, name, meta):
    meta["probe_sha256"] = hashlib.sha256(PROBE.encode("ascii")).hexdigest()
    compile_ea(mt5, run, name, meta, probe=True)


def publish(run, outbox):
    final = outbox / (run.name + ".zip")
    if final.exists():
        return
    tmp = outbox / f".{run.name}.{uuid4().hex}.tmp"
    with ZipFile(tmp, "w", ZIP_DEFLATED) as bundle:
        for path in sorted(run.iterdir()):
            if path.is_file() and (
                path.name in {"tester.ini", "result.json", "summary.json"}
                or re.fullmatch(r"diagnostico-(?:tarefa|[0-9]{2})\.txt", path.name)
                or path.suffix.lower() in {".htm", ".xml", ".png", ".gif"}
            ):
                bundle.write(path, path.name)
    tmp.replace(final)


def process(state, inbox, outbox, mt5):
    for run in sorted(state.iterdir()):
        if not run.is_dir() or not (run / "result.json").exists():
            continue
        result = load(run / "result.json")
        if result["status"] == "running":
            if "task" in result:
                run_job(mt5, run, result["task"], result)
            else:
                result.update(status="interrupted", finished=utc())
                save(run / "result.json", result)
        publish(run, outbox)
    tasks = sorted(inbox.glob("*.json"))
    for path in tasks:
        if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,47}", path.stem):
            continue
        run = state / path.stem.lower()
        if (run / "result.json").exists():
            continue
        try:
            data = load(path)
        except (OSError, ValueError):
            # O cliente de sincronização pode ainda estar transferindo o arquivo.
            continue
        run.mkdir(exist_ok=True)
        run_job(mt5, run, data)
        publish(run, outbox)


RUN_ERRORS = (OSError, ValueError, RuntimeError, subprocess.SubprocessError, ElementTree.ParseError)


def retryable(error):
    return isinstance(error, (RetryableRun, subprocess.TimeoutExpired)) or (
        isinstance(error, OSError) and getattr(error, "winerror", None) in (32, 33, 121)
    )


def failure_summary(error):
    if isinstance(error, subprocess.TimeoutExpired):
        return f"Subprocesso excedeu {error.timeout} s."
    if isinstance(error, (RetryableRun, InvalidBacktestReport)):
        return str(error)
    if isinstance(error, subprocess.CalledProcessError):
        return f"Subprocesso encerrou com código {error.returncode}."
    if isinstance(error, OSError):
        return f"Falha de I/O (errno={error.errno}, winerror={getattr(error, 'winerror', None)})."
    return "A etapa falhou. Consulte o diagnóstico da tentativa e o log local."


def write_diagnostics(path, attempt_dir, attempt, error=None):
    lines = [f"Etapa: {attempt.get('stage', 'validation')}", f"Estado: {attempt['status']}"]
    if attempt.get("terminal_phase"):
        lines.append(f"Fase do MT5: {attempt['terminal_phase']}")
    if error is not None:
        lines.append(f"{type(error).__name__}: {failure_summary(error)}")
    if attempt_dir is not None:
        for log in sorted(attempt_dir.glob("journal-*.log")):
            for line in text_file(log).splitlines():
                timestamp = re.search(r"\b\d{2}:\d{2}:\d{2}(?:\.\d{3})?\b", line)
                for event in SAFE_JOURNAL_EVENT.finditer(line):
                    lines.append(f"{timestamp[0] if timestamp else ''} {event[0]}".strip())
        compile_log = attempt_dir / "compile.log"
        if compile_log.is_file():
            for line in text_file(compile_log).splitlines():
                result = re.search(r"(?:Result|Resultado)\s*:\s*\d+\s+(?:errors?|erros?),\s*\d+\s+(?:warnings?|avisos?)", line, re.I)
                if result:
                    lines.append(result[0])
    path.write_text("\n".join(lines[:4] + lines[4:][-100:]) + "\n", encoding="utf-8")


def run_job(mt5, run, data, meta=None):
    manifest = run / "result.json"
    meta = meta or {"id": run.name, "status": "running", "started": utc(), "attempts": []}
    try:
        meta["task"] = parse_job(data)
    except ValueError as error:
        meta.update(status="failed", stage="validation", error_type=type(error).__name__, finished=utc())
        write_diagnostics(run / "diagnostico-tarefa.txt", None, meta, error)
        save(manifest, meta)
        return
    attempts = meta.setdefault("attempts", [])
    if attempts and attempts[-1]["status"] == "running":
        interrupted = attempts[-1]
        interrupted.update(status="interrupted", finished=utc())
        index = interrupted["attempt"]
        write_diagnostics(run / f"diagnostico-{index:02d}.txt", run / f"attempt-{index:02d}", interrupted)
    start_attempt = len(attempts) + 1
    if attempts and attempts[-1]["status"] != "interrupted" and not attempts[-1].get("retryable"):
        start_attempt = ATTEMPT_LIMIT + 1
    for index in range(start_attempt, ATTEMPT_LIMIT + 1):
        attempt_dir = run / f"attempt-{index:02d}"
        attempt_dir.mkdir(exist_ok=True)
        attempt = {
            "id": run.name, "task": meta["task"], "stage": "initialization",
            "attempt": index, "status": "running", "started": utc(),
        }
        attempts.append(attempt)
        save(manifest, meta)
        try:
            execute(mt5, attempt_dir, attempt)
        except RUN_ERRORS as error:
            (attempt_dir / "error.log").write_text(str(error), encoding="utf-8")
            attempt.update(
                status="failed", error_type=type(error).__name__,
                failure_reason=failure_summary(error), retryable=retryable(error),
            )
            write_diagnostics(run / f"diagnostico-{index:02d}.txt", attempt_dir, attempt, error)
        else:
            attempt["status"] = "completed"
        attempt["finished"] = utc()
        save(manifest, meta)
        if attempt["status"] == "completed" or not attempt.get("retryable") or index == ATTEMPT_LIMIT:
            break
        time.sleep(RETRY_DELAY)
    last = attempts[-1]
    for key, value in last.items():
        if key not in {"attempt", "started", "finished"}:
            meta[key] = value
    if last["status"] == "interrupted":
        meta.update(status="failed", error_type="InterruptionLimit", failure_reason="Orçamento de tentativas esgotado.")
        write_diagnostics(run / "diagnostico-tarefa.txt", None, meta)
    last_dir = run / f"attempt-{last['attempt']:02d}"
    for path in last_dir.iterdir():
        if path.is_file() and (
            path.name in {"summary.json", "tester.ini"} or path.suffix.lower() in {".htm", ".xml", ".png", ".gif"}
        ):
            shutil.copyfile(path, run / path.name)
    meta["finished"] = utc()
    save(manifest, meta)


def supervised(mt5, state, task_id):
    if not re.fullmatch(r"task_[a-zA-Z0-9_-]{1,80}", task_id or ""):
        raise ValueError("ID de tarefa inválido")
    if state.is_relative_to(mt5) or mt5.is_relative_to(state):
        raise ValueError("Estado do supervisor e MT5 devem ser separados")
    data = json.load(sys.stdin)
    runs = state / "runs"
    bundles = state / "bundles"
    for folder in (runs, bundles):
        folder.mkdir(parents=True, exist_ok=True)
    with locked(mt5 / ".alien-executor.lock"):
        run = runs / task_id
        run.mkdir(exist_ok=True)
        manifest = run / "result.json"
        meta = load(manifest) if manifest.is_file() else None
        if meta is None or meta["status"] == "running":
            run_job(mt5, run, data, meta)
        publish(run, bundles)


def diagnose(mt5, shared):
    info = {
        "python": sys.version.split()[0],
        "git_found": shutil.which("git") is not None,
        "google_drive_path_accessible": shared.is_dir(),
        "portable_marker": (mt5 / MARKER).is_file(),
        "terminal_found": (mt5 / "terminal64.exe").is_file(),
        "metaeditor_found": (mt5 / "metaeditor64.exe").is_file(),
        "remote_tcp": {},
    }
    for node in NODES:
        address, port = node.split(":")
        try:
            with socket.create_connection((address, int(port)), timeout=2):
                info["remote_tcp"][node] = True
        except OSError:
            info["remote_tcp"][node] = False
    print(json.dumps(info, indent=2))


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("command", choices=("diagnose", "once", "watch", "supervised"))
    cli.add_argument("--mt5", type=Path, required=True)
    cli.add_argument("--shared", type=Path)
    cli.add_argument("--task-id")
    cli.add_argument("--state", type=Path)
    args = cli.parse_args()
    mt5 = args.mt5.resolve()
    if args.command == "supervised":
        if args.state is None:
            cli.error("--state é obrigatório no modo supervised")
        check_terminal(mt5)
        supervised(mt5, args.state.resolve(), args.task_id)
        return
    if args.shared is None:
        cli.error("--shared é obrigatório")
    shared = args.shared.resolve()
    if args.command == "diagnose":
        diagnose(mt5, shared)
        return
    check_terminal(mt5)
    state = (args.state or mt5 / "alien-executor-state").resolve()
    if state.is_relative_to(shared) or shared.is_relative_to(state) or mt5.is_relative_to(shared):
        cli.error("Use diretórios separados para estado local, MT5 e Google Drive")
    if not shared.is_dir():
        cli.error("O diretório do Google Drive precisa existir")
    inbox, outbox = shared / "inbox", shared / "outbox"
    for folder in (state, inbox, outbox):
        folder.mkdir(parents=True, exist_ok=True)
    with locked(mt5 / ".alien-executor.lock"), locked(state / ".lock"):
        while True:
            try:
                process(state, inbox, outbox, mt5)
            except OSError as error:
                if args.command == "once":
                    raise
                print(f"{utc()} Erro de I/O: {type(error).__name__}", file=sys.stderr, flush=True)
            if args.command == "once":
                break
            time.sleep(20)


if __name__ == "__main__":
    main()
