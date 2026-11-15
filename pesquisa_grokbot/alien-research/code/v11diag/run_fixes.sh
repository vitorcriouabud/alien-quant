#!/bin/bash
cd /workspace/alien-research
first=1
for F in "$@"; do
  if [ $first = 1 ]; then EA=code/v11diag/ALIEN_V11_FIXLAB.mq5; first=0; else EA='ALIEN\ALIEN_V11_FIXLAB'; fi
  MT5_MODEL=4 MT5_RELAUNCH=0 bash code/run_mt5_test.sh "$EA" code/v11diag/$F.set XAUUSD M1 2026.10.30 2026.11.14 10000 "FIX_${F}_m4" || echo FAIL $F
  echo DONE $F
done
