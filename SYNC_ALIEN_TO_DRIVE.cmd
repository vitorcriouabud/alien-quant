@echo off
setlocal
cd /d "%~dp0"
set "SCRIPT=%~dp0sync_alien_artifacts_to_drive.ps1"
set "RAW=https://raw.githubusercontent.com/vitorcriouabud/alien-quant/data/dukascopy-xauusd-one-click-20261125/tools/sync_alien_artifacts_to_drive.ps1"

echo ============================================================
echo ALIEN - SINCRONIZACAO AUTOMATICA COM GOOGLE DRIVE
echo ============================================================
echo.
echo Destino esperado:
echo G:\Meu Drive\ALIEN - Transferencia Automatica
echo.
echo O programa somente COPIA arquivos relevantes.
echo Nao apaga originais, nao abre MT5 e nao envia ordens.
echo.

if not exist "%SCRIPT%" (
    echo Baixando o sincronizador...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '%RAW%' -OutFile '%SCRIPT%'"
    if errorlevel 1 goto download_error
)

if not exist "%SCRIPT%" goto download_error

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -IntervalMinutes 15
echo.
echo Sincronizador encerrado.
pause
exit /b 0

:download_error
echo.
echo ERRO: nao foi possivel baixar o sincronizador.
echo Verifique a internet e tente novamente.
pause
exit /b 1
