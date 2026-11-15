#!/bin/bash
# Roda testes um por vez, esperando o MT5 ficar livre (outro agente tambem usa o mesmo terminal).
cd /workspace/alien-research
idle(){ ! pgrep -f 'terminal64.exe' >/dev/null && ! pgrep -f 'metatester64' >/dev/null && [ -z "$(pgrep -f run_mt5_test.sh | grep -v $$)" ]; }
for F in "$@"; do
  for try in 1 2 3; do
    c=0; while [ $c -lt 4 ]; do if idle; then c=$((c+1)); else c=0; fi; sleep 8; done
    echo "START $F try $try $(date +%T)"
    MT5_MODEL=4 MT5_RELAUNCH=0 bash code/run_mt5_test.sh 'ALIEN\ALIEN_V11_FIXLAB' code/v11diag/$F.set XAUUSD M1 2026.10.30 2026.11.14 10000 "FIX_${F}_m4" > out/v11diag_run_$F.log 2>&1
    if grep -q "5444792" out/mt5/FIX_${F}_m4.htm 2>/dev/null && [ out/mt5/FIX_${F}_m4.htm -nt out/v11diag_run_$F.log.start ] ; then echo "DONE $F"; break; fi
    if iconv -f utf-16 -t utf-8 out/mt5/FIX_${F}_m4.htm 2>/dev/null | grep -q 5444792 && [ out/mt5/FIX_${F}_m4.htm -nt code/v11diag/$F.set ]; then echo "DONE $F"; break; fi
    echo "RETRY $F"
  done
done
