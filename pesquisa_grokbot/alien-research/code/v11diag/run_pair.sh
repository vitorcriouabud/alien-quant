#!/bin/bash
# usage: run_pair.sh <mq5> <set> <stem> [models...]
cd /workspace/alien-research
EA=$1; SET=$2; STEM=$3; shift 3
for M in "${@:-4}"; do
  MT5_MODEL=$M MT5_RELAUNCH=0 bash code/run_mt5_test.sh "$EA" "$SET" XAUUSD M1 2026.10.30 2026.11.14 10000 "${STEM}_m$M" || echo FAIL $M
done
