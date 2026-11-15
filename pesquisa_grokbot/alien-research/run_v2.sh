#!/bin/bash
# Reproduz a V2 (dados H1 em data/h1 e M1 em data/m1 via dukascopy-node; ver data/dl_m1.sh)
set -e; cd "$(dirname "$0")/code/v2"; PY=../../.venv/bin/python
$PY grid2.py && $PY analyze2.py && $PY portfolio2.py && $PY mtm.py
COSTS=RF $PY grid2.py && COSTS=RF $PY analyze2.py && COSTS=RF $PY portfolio2.py
cd ../smc && $PY grid_smc.py && $PY analyze_smc.py && $PY grid_smc.py Z && $PY analyze_smc.py _Z
