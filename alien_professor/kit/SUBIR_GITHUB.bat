@echo off
setlocal
title ALIEN - subir dados para o GitHub
cd /d "%~dp0"
if not exist "%~dp0SUBIR_GITHUB.ps1" (
    echo  ERRO: nao achei o SUBIR_GITHUB.ps1 nesta pasta.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SUBIR_GITHUB.ps1"
pause
endlocal
