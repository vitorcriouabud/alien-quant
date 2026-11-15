#!/bin/bash
# Portão completo antes de empacotar: compila tudo (0 erros/0 avisos), roda os mocks,
# confere sintaxe dos .ps1 (se tiver pwsh), ASCII/CRLF do kit e procura segredos.
set -u
P=/workspace/alien-professor; FAIL=0
step(){ echo "== $1"; }
bad(){ echo "FALHOU: $1"; FAIL=1; }
step "compilar"
OUT=$(bash $P/tools/build.sh 2>&1); echo "$OUT" | grep -E "Result:"
N=$(echo "$OUT" | grep -c "Result: 0 errors, 0 warnings")
[ "$N" -eq 4 ] || bad "compilação com erro/aviso"
step "mocks"
python3 $P/teste/check_mocks.py >/tmp/mocks.log 2>&1 && tail -1 /tmp/mocks.log || { tail -5 /tmp/mocks.log; bad "check_mocks"; }
python3 $P/teste/check_json_body.py || bad "check_json_body"
step "powershell"
PW=$(command -v pwsh || echo /tmp/pwsh/pwsh)
if [ -x "$PW" ]; then
  for f in $P/kit/*.ps1; do
    $PW -NoProfile -Command "\$e=\$null; [System.Management.Automation.Language.Parser]::ParseFile('$f',[ref]\$null,[ref]\$e) | Out-Null; if(\$e){exit 1}" || bad "sintaxe $f"
  done; echo "ps1 ok"
else echo "(sem pwsh: pulei a sintaxe dos .ps1)"; fi
for f in $P/kit/*.bat $P/kit/INSTALAR.ps1 $P/kit/SUBIR_GITHUB.ps1 $P/kit/ATUALIZAR.ps1; do
  python3 -c "import sys;b=open(sys.argv[1],'rb').read();assert all(c<128 for c in b),'ascii';assert b.count(b'\n')==b.count(b'\r\n'),'crlf'" "$f" || bad "ASCII/CRLF $f"
done
step "segredos"
PAT='AIza[0-9A-Za-z_-]{20,}|[0-9]{8,10}:AA[0-9A-Za-z_-]{20,}|AQ\.[0-9A-Za-z_-]{20,}'
if grep -rIEl "$PAT" $P/src $P/teste $P/tools $P/kit $P/*.mq5 $P/README_PT.md 2>/dev/null; then bad "segredo no código"; else echo "código limpo"; fi
if [ -f /workspace/ALIEN_PROFESSOR.zip ]; then
  T=$(mktemp -d); unzip -q /workspace/ALIEN_PROFESSOR.zip -d $T
  if grep -rIaEl "$PAT" $T >/dev/null 2>&1 || grep -raEl "$PAT" $T >/dev/null 2>&1; then bad "segredo no zip público"; else echo "zip público limpo"; fi
  rm -rf $T
fi
[ $FAIL -eq 0 ] && echo "TUDO OK" || { echo "PORTÃO FALHOU"; exit 1; }
