@echo off
setlocal
cd /d "%~dp0.."
echo.
echo === ALIEN LAB ^| COLETA AUTOMATICA DE CSV E RELATORIOS DO MT5 ===
echo Nenhuma ordem sera enviada. Nenhum arquivo sera publicado.
echo.
where py >nul 2>nul
if %errorlevel%==0 (
    py -3 "%~dp0collect_mt5_evidence.py" %*
) else (
    where python >nul 2>nul
    if %errorlevel%==0 (
        python "%~dp0collect_mt5_evidence.py" %*
    ) else (
        echo Python 3 nao encontrado. Use a instalacao de Python existente no ALIEN.
    )
)
echo.
echo Procure a pasta PACOTES_MT5 e anexe o ZIP nesta conversa.
pause
