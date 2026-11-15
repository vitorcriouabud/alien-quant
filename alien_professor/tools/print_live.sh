#!/bin/bash
# fecha o terminal GUI (sob o lock do tester), abre com o script APROF_PRINT e espera os prints
export WINEPREFIX=$HOME/.mt5 PATH="$HOME/.local/wine-11.22-staging/bin:$PATH" WINEDEBUG=-all DISPLAY=:2 WINEDLLOVERRIDES="mscoree=d;mshtml=d"
M=$WINEPREFIX/drive_c/Program
exec 8>/tmp/mt5_tester.lock; flock -w 1800 8 || { echo nolock; exit 1; }
pgrep -f 'terminal64.exe /config:C:\\Program\\Tester\\ini\\[^a]' && { echo "tester busy"; exit 1; }
rm -f $M/MQL5/Files/APROF_print_*
wine taskkill /IM terminal64.exe 8>&- >/dev/null 2>&1; for i in $(seq 1 25); do pgrep -f terminal64 >/dev/null || break; sleep 1; done
nohup wine 'C:\Program\terminal64.exe' '/config:C:\Program\Tester\ini\aprof_print.ini' /login:67316641 /server:RoboForex-ECN >/tmp/aprof_print.log 2>&1 8>&- &
for i in $(seq 1 60); do [ -f $M/MQL5/Files/APROF_print_2.png ] && break; sleep 3; done
sleep 3; mkdir -p /tmp/aprof; cp $M/MQL5/Files/APROF_print_*.png /tmp/aprof/ 2>/dev/null; ls /tmp/aprof
# volta o terminal ao normal (sem /config, senão o run_mt5_test.sh fica esperando)
wine taskkill /IM terminal64.exe 8>&- >/dev/null 2>&1; for i in $(seq 1 25); do pgrep -f terminal64 >/dev/null || break; sleep 1; done
nohup /home/box/.local/bin/mt5 terminal /login:67316641 /server:RoboForex-ECN >/tmp/mt5_gui_relaunch.log 2>&1 8>&- &
