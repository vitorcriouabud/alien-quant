@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js nao encontrado. Feche e reabra esta janela apos instalar o Node.js.
  pause
  exit /b 1
)
if not exist "dados" mkdir "dados"
rem Generate the first report before opening the local dashboard.
node "%~dp0alien-monitor.mjs" --once %*
if errorlevel 1 (
  pause
  exit /b 1
)
start "" "%~dp0dados\PAINEL_ALIEN.html"
node "%~dp0alien-monitor.mjs" %*
pause
