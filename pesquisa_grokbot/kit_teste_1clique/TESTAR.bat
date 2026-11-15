@echo off
setlocal
title Teste do robo - um clique
cd /d "%~dp0"
chcp 65001 >nul
echo.
echo  ============================================
echo    TESTE COM TICKS REAIS  -  um clique
echo    Nao opera conta real nem conta da mesa
echo  ============================================
echo.
if not exist "%~dp0TESTAR.ps1" (
    echo  ERRO: nao achei o arquivo TESTAR.ps1 nesta pasta.
    echo  Deixe TESTAR.bat e TESTAR.ps1 juntos.
    echo.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0TESTAR.ps1"
set ERR=%ERRORLEVEL%
echo.
if not "%ERR%"=="0" (
    echo  O teste nao terminou como esperado.
    echo  Se a janela criou um zip na Area de Trabalho,
    echo  pode me enviar mesmo assim.
    echo.
    pause
    exit /b %ERR%
)
pause
endlocal
