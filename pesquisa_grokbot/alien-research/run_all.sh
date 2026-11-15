#!/bin/bash
# Reprodução completa (~2 min após download). Requer node (npx) e python3.
set -e; cd "$(dirname "$0")"
[ -d .venv ] || (python3 -m venv .venv && .venv/bin/pip install -q numpy pandas numba pyarrow scipy)
mkdir -p data/raw out
if [ ! -f data/xau_m1_bidask.parquet ]; then
  for p in bid ask; do for y in 2023 2024 2025 2026; do to=$((y+1))-01-01; [ $y = 2026 ] && to=2026-11-14
    npx -y dukascopy-node -i xauusd -from $y-01-01 -to $to -t m1 -p $p -f csv -dir data/raw -fn xau_${p}_$y -bs 10 -bp 1000 -r 5; done; done
  .venv/bin/python code/load_data.py
fi
cd code
for a in "B" "A" "Z" "B nocap"; do ../.venv/bin/python run_grid.py $a; done
../.venv/bin/python f9ext.py; ../.venv/bin/python tod.py
../.venv/bin/python analyze.py B; ../.venv/bin/python analyze.py B_nocap
