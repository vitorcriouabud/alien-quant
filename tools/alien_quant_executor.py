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


def text_file(path):
    data = path.read_bytes()
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16", errors="replace")
    if data[:100].count(0) > 25:
        return data.decode("utf-16-le", errors="replace")
    return data.decode("utf-8-sig", errors="replace")


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
    if any(item == "?" or Path(item).resolve().parent == path for item in executables):
        raise RuntimeError("MT5 ou MetaEditor dedicado já aberto, ou caminho do processo inacessível")


def require_clean_source():
    paths = ["MQL5/Experts/" + EA.name, "MQL5/Profiles/Tester/" + PRESET.name]
    git = ["git", "-C", str(REPO)]
    result = subprocess.run(
        git + ["status", "--porcelain", "--"] + paths,
        capture_output=True, text=True, check=True, timeout=15,
    )
    if result.stdout.strip():
        raise RuntimeError("Fonte ou preset com alterações locais. Registre a revisão primeiro.")
    return subprocess.check_output(git + ["rev-parse", "HEAD"], text=True, timeout=15).strip()


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
    result = subprocess.run(command, cwd=mt5, timeout=300)
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
    require_idle(mt5)
    meta["revision"] = require_clean_source()
    meta["sha256_source"] = digest(EA)
    meta["sha256_repository_preset"] = digest(PRESET)
    if job["mode"] in ("local", REMOTE_SWEEP):
        compile_ea(mt5, run, name, meta)
    else:
        compile_probe(mt5, run, name, meta)
    preset = prepare_preset(mt5, name, job["mode"])
    meta["sha256_tester_preset"] = digest(preset)
    demo = check_terminal(mt5)
    common = f"[Common]\nServer={demo['server']}\nNewsEnable=0\n"
    settings = tester_ini(job, name, preset.name)
    (run / "tester.ini").write_text(common + "\n" + settings, encoding="ascii")
    private_settings = run / "terminal-start.ini"
    private_settings.write_text(common + f"Login={demo['login']}\n\n" + settings, encoding="ascii")
    report_dir = mt5 / "alien-executor-reports" / name
    report_dir.mkdir(parents=True)
    require_idle(mt5)
    tester_logs = mt5 / "Tester/logs"
    offsets = {p.name: p.stat().st_size for p in tester_logs.glob("*.log")}
    try:
        result = subprocess.run(
            [str(mt5 / "terminal64.exe"), "/portable", f"/config:{private_settings}"],
            cwd=mt5, timeout=3600,
        )
    finally:
        private_settings.unlink(missing_ok=True)
        collect_journal(tester_logs, offsets, run)
    meta["terminal_exit"] = result.returncode
    suffix = ".htm" if job["mode"] == "local" else ".xml"
    report = report_dir / ("report" + suffix)
    if result.returncode or not report.is_file() or not report.stat().st_size:
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
    metrics["exp_id"] = report.parent.name
    save(report.parent / "summary.json", metrics)


def verify_real_ticks(run, meta):
    journal = "\n".join(text_file(path) for path in sorted(run.glob("journal-*.log")))
    fallback = re.search(
        r"no real ticks[^\n]*tick generation used|"
        r"real ticks (?:discarded|missing) for [1-9][0-9]* minute|"
        r"real ticks unavailable[^\n]*generat",
        journal, re.I,
    )
    confirmed = re.search(
        r"real ticks begin from|real ticks synchronization completed|"
        r"generat(?:ing|ed) based on real ticks|using real ticks",
        journal, re.I,
    )
    meta["real_ticks_confirmed"] = bool(confirmed and not fallback)
    if fallback:
        raise InvalidBacktestReport("O MT5 substituiu ticks reais por geração de ticks.")
    if not confirmed:
        raise InvalidBacktestReport("O diário do MT5 não confirma uso de ticks reais.")


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


def run_job(mt5, run, data):
    meta = {"id": run.name, "status": "running", "started": utc()}
    save(run / "result.json", meta)
    try:
        meta["task"] = parse_job(data)
        execute(mt5, run, meta)
        meta["status"] = "completed"
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, ElementTree.ParseError) as error:
        (run / "error.log").write_text(str(error), encoding="utf-8")
        meta.update(status="failed", error_type=type(error).__name__)
    meta["finished"] = utc()
    save(run / "result.json", meta)


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
        if manifest.is_file():
            meta = load(manifest)
            if meta["status"] == "running":
                meta.update(status="interrupted", finished=utc())
                save(manifest, meta)
        else:
            run_job(mt5, run, data)
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
