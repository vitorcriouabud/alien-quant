#!/bin/bash
set -e
python3 - <<'PY'
import codecs,os
src='/workspace/alien-professor/src/'
s=open(src+'ind_head.mq5').read()+open(src+'core.mqh').read()+open(src+'engine.mqh').read()+open(src+'painel.mqh').read()+open(src+'ind_tail.mq5').read()
M='/home/box/.mt5/drive_c/Program/MQL5'
os.makedirs(M+'/Indicators/ALIEN',exist_ok=True); os.makedirs(M+'/Experts/ALIEN',exist_ok=True)
for out in ['/workspace/alien-professor/ALIEN_PROFESSOR.mq5',M+'/Indicators/ALIEN/ALIEN_PROFESSOR.mq5']:
    open(out,'wb').write(codecs.BOM_UTF8+s.encode('utf-8'))
open(M+'/Experts/ALIEN/ALIEN_PROFESSOR_core.mqh','wb').write(codecs.BOM_UTF8+(open(src+'core.mqh').read()+open(src+'engine.mqh').read()+open(src+'painel.mqh').read()).encode('utf-8'))
tg=open(src+'telegram.mq5').read()+open(src+'ai.mqh').read()
for out in [M+'/Experts/ALIEN/ALIEN_PROFESSOR_TELEGRAM.mq5','/workspace/alien-professor/ALIEN_PROFESSOR_TELEGRAM.mq5']:
    open(out,'wb').write(codecs.BOM_UTF8+tg.encode('utf-8'))
open(M+'/Experts/ALIEN/ALIEN_PROFESSOR_TESTE.mq5','wb').write(codecs.BOM_UTF8+open(src+'harness.mq5').read().encode('utf-8'))
PY
M=/home/box/.mt5/drive_c/Program/MQL5
for f in 'Experts\ALIEN\ALIEN_PROFESSOR_TELEGRAM.mq5' 'Indicators\ALIEN\ALIEN_PROFESSOR.mq5' 'Experts\ALIEN\ALIEN_PROFESSOR_TESTE.mq5'; do /home/box/.local/bin/mt5 compile "C:\\Program\\MQL5\\$f" >/dev/null 2>&1 || true; done
for l in $M/Experts/ALIEN/ALIEN_PROFESSOR_TELEGRAM.log $M/Indicators/ALIEN/ALIEN_PROFESSOR.log $M/Experts/ALIEN/ALIEN_PROFESSOR_TESTE.log; do iconv -f utf-16 -t utf-8 $l | grep -E "error|warning" ; done
cp $M/Indicators/ALIEN/ALIEN_PROFESSOR.ex5 $M/Experts/ALIEN/ALIEN_PROFESSOR_TELEGRAM.ex5 /workspace/alien-professor/
python3 - <<'PY'
import codecs
src='/workspace/alien-professor/src/'
s=open(src+'auto_head.mq5').read()+open(src+'core.mqh').read()+open(src+'engine.mqh').read()+open(src+'painel.mqh').read()+open(src+'auto_tg.mqh').read()+open(src+'ai.mqh').read()+open(src+'auto_tail.mq5').read().replace('//@@CHAT@@',open(src+'auto_chat.mqh').read()+open(src+'auto_learn.mqh').read()+open(src+'auto_agente.mqh').read())
for out in ['/workspace/alien-professor/ALIEN_PROFESSOR_AUTO.mq5','/home/box/.mt5/drive_c/Program/MQL5/Experts/ALIEN/ALIEN_PROFESSOR_AUTO.mq5']:
    open(out,'wb').write(codecs.BOM_UTF8+s.encode('utf-8'))
PY
/home/box/.local/bin/mt5 compile 'C:\Program\MQL5\Experts\ALIEN\ALIEN_PROFESSOR_AUTO.mq5' >/dev/null 2>&1 || true
iconv -f utf-16 -t utf-8 $M/Experts/ALIEN/ALIEN_PROFESSOR_AUTO.log | grep -E "error|warning"
cp $M/Experts/ALIEN/ALIEN_PROFESSOR_AUTO.ex5 /workspace/alien-professor/
