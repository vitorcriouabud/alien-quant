@echo off
setlocal
title ALIEN VIGIA - instalar
cd /d "%~dp0"
chcp 65001 >nul
echo.
echo  ============================================
echo    ALIEN VIGIA - mantem o MT5 sempre aberto
echo  ============================================
echo.
if not exist "%~dp0VIGIA_MT5.ps1" (
    echo  ERRO: deixe VIGIA_INSTALAR.bat e VIGIA_MT5.ps1 na mesma pasta.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0VIGIA_MT5.ps1" -Instalar
pause
endlocal
