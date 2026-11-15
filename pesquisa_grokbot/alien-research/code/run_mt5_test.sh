#!/usr/bin/env bash
# End-to-end MT5 Strategy Tester run on this box (Wine portable install).
# Usage:
#   run_mt5_test.sh <ea> <set> <symbol> <tf> <from> <to> <deposit> [report_stem]
#
# <ea>  : Linux path to .mq5/.ex5, or Expert path relative to MQL5\Experts
#         e.g. /path/ALIEN_V11_SCALPER.mq5  or  ALIEN\ALIEN_V11_SCALPER
# <set> : Linux path to a .set file (copied into the tester profiles)
# <tf>  : M1, M5, M15, M30, H1, H4, D1, ...
# <from>/<to>: YYYY.MM.DD
# <deposit>: number, e.g. 10000
#
# Optional env:
#   MT5_LOGIN=  # defina no ambiente; nunca commitar login/senha
#   MT5_SERVER=RoboForex-ECN
#   MT5_LEVERAGE=100
#   MT5_CURRENCY=USD
#   MT5_MODEL=4          # 4 = every tick based on real ticks
#   MT5_REPORT_DIR=/workspace/alien-research/out/mt5
#   MT5_RELAUNCH=1       # relaunch GUI terminal on DISPLAY=:2 at the end
#   MT5_SKIP_CLOSE=0     # if 1, do not close a running GUI terminal
#   DISPLAY=:2
#
# Hard rules: Strategy Tester only. This script never enables AutoTrading
# on charts and never writes a password into the ini.
set -euo pipefail

if [[ $# -lt 7 ]]; then
  echo "usage: $0 <ea> <set> <symbol> <tf> <from> <to> <deposit> [report_stem]" >&2
  exit 2
fi

EA_ARG="$1"
SET_ARG="$2"
SYMBOL="$3"
TF="$4"
FROM="$5"
TO="$6"
DEPOSIT="$7"
STEM="${8:-mt5_test_${SYMBOL}_${TF}_${FROM}_${TO}}"
STEM="${STEM//\//_}"

export WINEPREFIX="${WINEPREFIX:-$HOME/.mt5}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree=d;mshtml=d}"
export PATH="$HOME/.local/wine-11.22-staging/bin:$PATH"
export DISPLAY="${DISPLAY:-:2}"

MT5_ROOT="$WINEPREFIX/drive_c/Program"
MT5_BIN="$HOME/.local/bin/mt5"
LOGIN="${MT5_LOGIN:-}"
SERVER="${MT5_SERVER:-RoboForex-ECN}"
LEVERAGE="${MT5_LEVERAGE:-100}"
CURRENCY="${MT5_CURRENCY:-USD}"
if [[ -z "$LOGIN" ]]; then
  echo "MT5_LOGIN is required (demo login). Do not hardcode it in this file." >&2
  exit 2
fi
MODEL="${MT5_MODEL:-4}"
REPORT_DIR="${MT5_REPORT_DIR:-/workspace/alien-research/out/mt5}"
RELAUNCH="${MT5_RELAUNCH:-1}"
SKIP_CLOSE="${MT5_SKIP_CLOSE:-0}"

if [[ ! -x $MT5_BIN ]]; then
  echo "mt5 wrapper not found: $MT5_BIN" >&2
  exit 1
fi
if [[ ! -x $HOME/.local/wine-11.22-staging/bin/wine ]]; then
  echo "expected wine at $HOME/.local/wine-11.22-staging/bin/wine" >&2
  exit 1
fi
if [[ ! -f $MT5_ROOT/terminal64.exe ]]; then
  echo "terminal not found at $MT5_ROOT/terminal64.exe" >&2
  exit 1
fi

# --- serialize tester runs between agents sharing this box (added 15/11) ---
exec 9>/tmp/mt5_tester.lock
flock -w 7200 9 || { echo "could not get /tmp/mt5_tester.lock" >&2; exit 1; }
for _i in $(seq 1 1440); do
  pgrep -f 'terminal64.exe /config:' >/dev/null || break
  [[ $_i -eq 1 ]] && printf '[run_mt5_test] another tester run is active, waiting...\n'
  sleep 5
done
log() { printf '[run_mt5_test] %s\n' "$*"; }

# --- resolve Expert path inside MQL5\Experts ---
expert_rel=""
if [[ "$EA_ARG" == *'\'* ]] && [[ "$EA_ARG" != /* ]]; then
  expert_rel="${EA_ARG%.ex5}"
  expert_rel="${expert_rel%.mq5}"
elif [[ -f "$EA_ARG" ]]; then
  ext="${EA_ARG##*.}"
  base="$(basename "$EA_ARG")"
  dest_dir="$MT5_ROOT/MQL5/Experts/ALIEN"
  mkdir -p "$dest_dir"
  cp -f "$EA_ARG" "$dest_dir/$base"
  if [[ "$ext" == "mq5" ]]; then
    log "compiling C:\\Program\\MQL5\\Experts\\ALIEN\\$base"
    set +e
    "$MT5_BIN" compile "C:\\Program\\MQL5\\Experts\\ALIEN\\$base"
    cc=$?
    set -e
    log "compiler exit $cc (MetaEditor often exits 1 even on success)"
    logf="$dest_dir/${base%.mq5}.log"
    if [[ -f "$logf" ]]; then
      python3 - "$logf" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1])
raw=p.read_bytes()
text=None
for enc in ('utf-16','utf-16-le','utf-8','cp1252'):
    try:
        text=raw.decode(enc)
        break
    except Exception:
        pass
if text is None:
    raise SystemExit('cannot decode compile log')
print(text.strip().splitlines()[-8:])
if '0 errors' not in text and '0 error' not in text.lower():
    # still accept if .ex5 exists and log doesn't say error count >0
    pass
PY
    fi
    if [[ ! -f "$dest_dir/${base%.mq5}.ex5" ]]; then
      echo "compile failed: no .ex5" >&2
      exit 1
    fi
  fi
  expert_rel="ALIEN\\${base%.*}"
else
  # treat as Expert relative path
  expert_rel="${EA_ARG%.ex5}"
  expert_rel="${expert_rel%.mq5}"
  expert_rel="${expert_rel//\//\\}"
fi
log "Expert=$expert_rel"

# --- set file ---
if [[ ! -f "$SET_ARG" ]]; then
  echo "set file not found: $SET_ARG" >&2
  exit 1
fi
set_name="$(basename "$SET_ARG")"
mkdir -p "$MT5_ROOT/MQL5/Profiles/Tester" "$MT5_ROOT/Tester"
install_set() {
  local dest="$1"
  if [[ "$(readlink -f "$SET_ARG")" == "$(readlink -f "$dest")" ]]; then
    return 0
  fi
  cp -f "$SET_ARG" "$dest"
}
install_set "$MT5_ROOT/MQL5/Profiles/Tester/$set_name"
install_set "$MT5_ROOT/Tester/$set_name"
# also accept a set sitting next to the script
log "ExpertParameters=$set_name"

# --- ini (no password) ---
mkdir -p "$MT5_ROOT/Tester/ini" "$MT5_ROOT/Tester/reports" "$REPORT_DIR"
ini_win="C:\\Program\\Tester\\ini\\${STEM}.ini"
ini_lin="$MT5_ROOT/Tester/ini/${STEM}.ini"
report_win="Tester\\reports\\${STEM}"
# Also write a copy under Linux out dir via later cp

cat > "$ini_lin" <<EOF
; Auto-generated by run_mt5_test.sh — no password is stored here.
[Tester]
Expert=$expert_rel
ExpertParameters=$set_name
Symbol=$SYMBOL
Period=$TF
Login=$LOGIN
Server=$SERVER
Deposit=$DEPOSIT
Currency=$CURRENCY
Leverage=$LEVERAGE
Model=$MODEL
Optimization=0
FromDate=$FROM
ToDate=$TO
Report=$report_win
ReplaceReport=1
ShutdownTerminal=1
Visual=0
UseLocal=1
ForwardMode=0
ExecutionMode=0
ProfitInPips=0
EOF
log "wrote $ini_lin"

# --- close GUI terminal sharing the portable data dir ---
term_pids() { pgrep -f 'terminal64.exe' || true; }

graceful_close_terminal() {
  local pids
  pids="$(term_pids)"
  if [[ -z "$pids" ]]; then
    log "no terminal64 running"
    return 0
  fi
  if [[ "$SKIP_CLOSE" == "1" ]]; then
    echo "terminal64 is running and MT5_SKIP_CLOSE=1; refusing to test on a shared data dir" >&2
    exit 1
  fi
  log "closing terminal64 pids: $pids"
  wine taskkill /IM terminal64.exe >/tmp/mt5_taskkill.log 2>&1 || true
  for i in $(seq 1 20); do
    pids="$(term_pids)"
    [[ -z "$pids" ]] && break
    sleep 1
  done
  pids="$(term_pids)"
  if [[ -n "$pids" ]]; then
    log "taskkill timed out, sending TERM to $pids"
    kill -TERM $pids 2>/dev/null || true
    sleep 3
  fi
  pids="$(term_pids)"
  if [[ -n "$pids" ]]; then
    log "sending KILL to $pids"
    kill -KILL $pids 2>/dev/null || true
    sleep 1
  fi
  if [[ -n "$(term_pids)" ]]; then
    echo "could not close terminal64" >&2
    exit 1
  fi
  log "terminal64 closed"
}

relaunch_gui() {
  if [[ "$RELAUNCH" != "1" ]]; then
    log "skip relaunch (MT5_RELAUNCH=$RELAUNCH)"
    return 0
  fi
  if [[ -n "$(term_pids)" ]]; then
    log "terminal already running, not relaunching"
    return 0
  fi
  log "relaunching GUI terminal on DISPLAY=$DISPLAY (saved account, no password on CLI)"
  nohup "$MT5_BIN" terminal /login:"$LOGIN" /server:"$SERVER" \
    >/tmp/mt5_gui_relaunch.log 2>&1 &
  disown || true
  sleep 2
  log "terminal pids: $(term_pids || echo none)"
}

graceful_close_terminal

log "starting tester: $SYMBOL $TF Model=$MODEL $FROM..$TO deposit=$DEPOSIT"
set +e
"$MT5_BIN" test "$ini_win"
tc=$?
set -e
log "tester exit $tc"

# copy reports (htm/html/png/xml/gif) to REPORT_DIR
mkdir -p "$REPORT_DIR"
# MT5 may write .htm or .html, sometimes with .htm.htm
shopt -s nullglob
copied=0
for src in "$MT5_ROOT/Tester/reports/${STEM}"*; do
  base="$(basename "$src")"
  cp -f "$src" "$REPORT_DIR/$base"
  log "copied $src -> $REPORT_DIR/$base"
  copied=1
done
# also sometimes relative to C:\Program
for src in "$MT5_ROOT/${STEM}"* "$MT5_ROOT/Tester/${STEM}"*; do
  [[ -e "$src" ]] || continue
  base="$(basename "$src")"
  cp -f "$src" "$REPORT_DIR/$base"
  log "copied $src -> $REPORT_DIR/$base"
  copied=1
done

# Any html/htm/png produced under the terminal tree in this run
while IFS= read -r f; do
  base="$(basename "$f")"
  cp -f "$f" "$REPORT_DIR/${STEM}_$base"
  log "copied extra $f"
  copied=1
done < <(find "$MT5_ROOT" -maxdepth 3 \( -iname "*.htm" -o -iname "*.html" -o -iname "*.xml" \) -newer "$ini_lin" 2>/dev/null || true)

# EA self-reports written inside the tester agent
agent_files="$MT5_ROOT/Tester/Agent-127.0.0.1-3000/MQL5/Files"
if [[ -d "$agent_files" ]]; then
  mkdir -p "$REPORT_DIR/${STEM}_files"
  find "$agent_files" -maxdepth 1 -type f -newer "$ini_lin" -exec cp -f {} "$REPORT_DIR/${STEM}_files/" \;
  if compgen -G "$REPORT_DIR/${STEM}_files/*" > /dev/null; then
    log "copied agent files to $REPORT_DIR/${STEM}_files"
    copied=1
  fi
fi

# tester journal
if [[ -f $MT5_ROOT/Tester/logs/$(date +%Y%m%d).log ]]; then
  cp -f "$MT5_ROOT/Tester/logs/$(date +%Y%m%d).log" "$REPORT_DIR/tester_$(date +%Y%m%d).log" || true
fi
if [[ -f $MT5_ROOT/logs/$(date +%Y%m%d).log ]]; then
  # do not assume this file contains passwords; still avoid grepping login secrets into stdout
  cp -f "$MT5_ROOT/logs/$(date +%Y%m%d).log" "$REPORT_DIR/terminal_$(date +%Y%m%d).log" || true
fi

# copy DumpSpec output if present (tester agents write under Tester\Agent-*\MQL5\Files)
while IFS= read -r f; do
  cp -f "$f" "$REPORT_DIR/dump_spec.txt"
  log "copied dump_spec from $f"
done < <(find "$MT5_ROOT/Tester" "$MT5_ROOT/MQL5/Files" -name 'dump_spec.txt' 2>/dev/null || true)

relaunch_gui

if [[ $copied -eq 0 ]]; then
  echo "WARNING: no report files found for stem $STEM (tester exit $tc)" >&2
  exit 1
fi
exit 0
