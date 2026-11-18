@echo off
setlocal
title ALIEN - COLETAR RELATORIO
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ALIEN_ROBOFOREX.ps1" -Acao Coletar
echo.
echo Envie ENVIAR_AO_CHATGPT.zip ao ChatGPT.
pause
