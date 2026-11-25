@echo off
setlocal
cd /d "%~dp0"
set "SCRIPT=%~dp0tools\download_xauusd_public_ticks.py"

echo ============================================================
echo ALIEN - DOWNLOAD AUTOMATICO DE TICKS XAUUSD
echo Fonte: Dukascopy public feed (Bid/Ask)
echo Periodo: 2024, 2025 e 2026 ate a ultima data publicada
echo ============================================================
echo.
echo NAO usa MT5, NAO abre ordens, NAO precisa de Node ou pandas.
echo Download estimado: aproximadamente 1.6 GB.
echo Os arquivos serao salvos em DATA\TICKS.
echo.

if not exist "%SCRIPT%" (
    if not exist "%~dp0tools" mkdir "%~dp0tools"
    echo Baixando o motor automatico do GitHub...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/vitorcriouabud/alien-quant/data/dukascopy-xauusd-one-click-20261125/tools/download_xauusd_public_ticks.py' -OutFile '%SCRIPT%'"
    if errorlevel 1 goto download_error
)

if not exist "%SCRIPT%" goto download_error

where py >nul 2>nul
if not errorlevel 1 goto use_py

where python >nul 2>nul
if errorlevel 1 goto no_python

:use_python
python "%SCRIPT%" --years 2024 2025 2026 --output-dir "DATA\TICKS" --workers 3
set "RESULT=%ERRORLEVEL%"
goto finish

:use_py
py -3 "%SCRIPT%" --years 2024 2025 2026 --output-dir "DATA\TICKS" --workers 3
set "RESULT=%ERRORLEVEL%"
goto finish

:no_python
echo ERRO: Python 3 nao foi encontrado neste Windows.
echo Instale Python 3 e marque Add Python to PATH.
set "RESULT=1"
goto finish

:download_error
echo ERRO: nao foi possivel baixar o motor pelo GitHub.
echo Confira a conexao e tente novamente.
set "RESULT=1"
goto finish

:finish
echo.
if not "%RESULT%"=="0" (
    echo O download ficou incompleto ou houve falha de verificacao.
    echo Execute este mesmo arquivo novamente: ele retoma os arquivos faltantes.
) else (
    echo DOWNLOAD E VERIFICACAO CONCLUIDOS.
)
pause
exit /b %RESULT%
