#!/bin/bash
S=/workspace/alien-research/code/run_mt5_test.sh
export MT5_REPORT_DIR=/workspace/alien-professor/tools/out
MT5_RELAUNCH=0 MT5_MODEL=4 $S 'ALIEN\ALIEN_PROFESSOR_AUTO' /workspace/alien-professor/tools/AUTO.set XAUUSD M1 2026.10.30 2026.11.14 5000 auto_xau_real > /tmp/auto_real.log 2>&1; echo "real rc=$?"
MT5_RELAUNCH=1 MT5_MODEL=0 $S 'ALIEN\ALIEN_PROFESSOR_AUTO' /workspace/alien-professor/tools/AUTO.set XAUUSD M1 2025.01.01 2025.12.31 5000 auto_xau_2025gen > /tmp/auto_gen.log 2>&1; echo "gen rc=$?"
