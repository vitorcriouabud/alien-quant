@echo off
setlocal
cd /d "%~dp0"
node "%~dp0alien-monitor.mjs" --once %*
if errorlevel 1 (
  echo Se o monitor ja estiver aberto, o arquivo ja e atualizado a cada 30 segundos.
  pause
  exit /b 1
)
echo Arquivo para enviar: %~dp0dados\ENVIAR_AO_CHATGPT.json
start "" "%~dp0dados"
pause
