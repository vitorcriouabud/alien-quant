#!/bin/bash
/workspace/alien-professor/tools/build.sh > /tmp/aprof_build.log 2>&1
S=/workspace/alien-research/code/run_mt5_test.sh
export MT5_REPORT_DIR=/workspace/alien-professor/tools/out
MT5_RELAUNCH=1 MT5_MODEL=0 $S 'ALIEN\ALIEN_PROFESSOR_AUTO' /workspace/alien-professor/tools/AUTO_semDD.set XAUUSD M1 2025.01.01 2025.12.31 5000 auto_xau_2025gen_semDD > /tmp/auto_gen2.log 2>&1; echo "gen2 rc=$?"
