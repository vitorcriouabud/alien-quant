@echo off
setlocal
title ALIEN - ROBOFOREX JA LOGADO - UM CLIQUE
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ALIEN_ROBOFOREX.ps1" -Acao Executar
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (echo Preparacao ou teste finalizado. Veja ENVIAR_AO_CHATGPT.zip) else (echo Erro detectado. Envie ENVIAR_AO_CHATGPT.zip ao ChatGPT.)
echo.
pause
exit /b %RESULT%
