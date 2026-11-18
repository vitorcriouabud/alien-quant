@echo off
title ALIEN - CORRECAO ROBOFOREX
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ALIEN_ROBOFOREX.ps1" -Acao Preparar
echo.
echo Se houver erro, envie ENVIAR_AO_CHATGPT.zip ao ChatGPT.
pause
