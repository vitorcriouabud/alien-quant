@echo off
setlocal
title ALIEN PROFESSOR - instalar
cd /d "%~dp0"
chcp 65001 >nul
echo.
echo  ============================================
echo    ALIEN PROFESSOR - instalar em 1 clique
echo  ============================================
echo.
if not exist "%~dp0INSTALAR.ps1" (
    echo  ERRO: nao achei o INSTALAR.ps1 nesta pasta. Deixe os arquivos juntos.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALAR.ps1"
pause
endlocal
