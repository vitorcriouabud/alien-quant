@echo off
setlocal
cd /d "%~dp0"

where python >nul 2>&1
if errorlevel 1 (
  echo FALHA: Python ausente. Nao instale repetidamente: configurar Python uma unica vez.
  exit /b 1
)
python -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)"
if errorlevel 1 (
  echo FALHA: Python 3.10 ou mais recente requerido.
  exit /b 1
)
python -c "import numpy,pandas,pytest"
if errorlevel 1 (
  echo FALHA: dependencias ausentes; rode UMA vez: python -m pip install -r requirements.txt
  exit /b 1
)
python -m pytest tests -q
if errorlevel 1 (
  echo FALHA: testes locais nao passaram; execucao cancelada.
  exit /b 1
)
if "%~1"=="" (
  echo Testes concluidos. Informe o caminho do CSV como primeiro argumento.
  echo Exemplo: INICIAR_LAB.cmd "C:\dados\ALIEN_LAB_M1_XAUUSD.csv"
  echo Parametros detalhados: python -m alienlab.nightly --help
  exit /b 0
)

REM Modo conservador para notebook de 8 GB. +2 UTC FIXO E APENAS SUPOSICAO.
python -m alienlab.nightly --csv "%~1" --outdir resultados --timestamp-kind server --server-utc-offset 2 --horizons 15 --slippage 10 --position-policy one_per_hypothesis
if errorlevel 1 (
  echo FALHA: consulte resultados\checkpoint.json. Nunca declarar sucesso sem ZIP.
  exit /b 1
)
if not exist "resultados\ALIEN_LAB_V1_resultado.zip" (
  echo FALHA: ZIP ausente apesar do processo ter terminado.
  exit /b 1
)
echo Triagem exploratoria em resultados\ALIEN_LAB_V1_resultado.zip
exit /b 0
