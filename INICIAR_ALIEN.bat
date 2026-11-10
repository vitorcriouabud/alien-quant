@echo off
rem ALIEN - inicia MT5 (com o robo no grafico XAUUSD M1) + vigia (Telegram + Mission Control)
rem De dois cliques neste arquivo. O vigia religa o que cair.
start "" "C:\Program Files\RoboForex MT5 Terminal\terminal64.exe" /profile:Default
timeout /t 5 /nobreak >nul
start "" /min "C:\Users\notebook\AppData\Local\Programs\Python\Python313\pythonw.exe" "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools\alien_watchdog.py"
echo ALIEN iniciado. Pode fechar esta janela.
timeout /t 3 >nul
