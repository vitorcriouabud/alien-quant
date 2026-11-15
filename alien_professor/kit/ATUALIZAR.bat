@echo off
setlocal
title ALIEN PROFESSOR - atualizar
cd /d "%~dp0"
echo.
echo  ============================================
echo    ALIEN PROFESSOR - atualizar pelo GitHub
echo  ============================================
echo.
if not exist "%~dp0ATUALIZAR.ps1" (
    echo  ERRO: nao achei o ATUALIZAR.ps1 nesta pasta. Extraia o zip inteiro antes.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ATUALIZAR.ps1"
pause
endlocal
