@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo ALIEN - DOWNLOAD AUTOMATICO DE TICKS XAUUSD
echo Fonte: Dukascopy public feed (Bid/Ask)
echo Periodo: 2024, 2025 e 2026 ate a ultima data publicada
echo ============================================================
echo.
echo Este processo NAO usa MT5, NAO abre ordens e NAO precisa de Node.
echo Os arquivos serao salvos em DATA\TICKS.
echo O download completo pode ocupar aproximadamente 1.6 GB.
echo.

where py >nul 2>nul
if not errorlevel 1 goto use_py

where python >nul 2>nul
if errorlevel 1 goto no_python

:use_python
python "tools\download_xauusd_public_ticks.py" --years 2024 2025 2026 --output-dir "DATA\TICKS" --workers 3
set "RESULT=%ERRORLEVEL%"
goto finish

:use_py
py -3 "tools\download_xauusd_public_ticks.py" --years 2024 2025 2026 --output-dir "DATA\TICKS" --workers 3
set "RESULT=%ERRORLEVEL%"
goto finish

:no_python
echo ERRO: Python 3 nao foi encontrado neste Windows.
echo Instale Python 3 e marque Add Python to PATH.
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
