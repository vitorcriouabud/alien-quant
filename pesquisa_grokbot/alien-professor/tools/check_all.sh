#!/bin/bash
cd /workspace/alien-professor/tools
for S in XAUUSD .US500Cash; do
 MT5_RELAUNCH=0 MT5_VISUAL=0 MT5_MODEL=1 MT5_REPORT_DIR=/workspace/alien-professor/tools/out ./run_visual.sh 'ALIEN\ALIEN_PROFESSOR_TESTE' APROF_TESTE.set $S M1 2026.11.09 2026.11.13 5000 aprof_m1_${S#.} > /tmp/aprof_chk_${S#.}.log 2>&1
 echo "$S rc=$?"
done
./print_live.sh
