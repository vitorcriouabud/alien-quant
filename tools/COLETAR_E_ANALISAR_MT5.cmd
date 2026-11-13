@echo off
setlocal
cd /d "%~dp0.."
echo.
echo =====================================================
echo  ALIEN LAB - COLETAR E ANALISAR EVIDENCIAS MT5
 echo =====================================================
echo O robô e as ordens NAO serao alterados.
echo.
where py >nul 2>nul
if %errorlevel%==0 (
    set "PYTHON=py -3"
) else (
    where python >nul 2>nul
    if errorlevel 1 (
        echo ERRO: Python 3 nao encontrado. Use o Python ja instalado no ALIEN.
        pause
        exit /b 1
    )
    set "PYTHON=python"
)
%PYTHON% "%~dp0collect_mt5_evidence.py" %*
if errorlevel 1 (
    echo Coleta nao concluiu. Verifique o aviso acima.
    pause
    exit /b 2
)
%PYTHON% "%~dp0analyze_mt5_evidence.py" --latest
if errorlevel 1 (
    echo Analise nao concluiu. Verifique o aviso acima.
    pause
    exit /b 3
)
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$p=Get-ChildItem -LiteralPath '.\PACOTES_MT5' -Filter 'ALIEN_EVIDENCIAS_*.zip' ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First 1; if($p) { Join-Path (Join-Path (Resolve-Path '.\RELATORIOS_MT5') $p.BaseName) 'ALIEN_AUDITORIA.html' }"`) do (
  if exist "%%A" start "" "%%A"
)
echo.
echo Relatorio local gerado: pasta RELATORIOS_MT5.
echo Para analisar nesta conversa, envie apenas os arquivos desejados.
pause
