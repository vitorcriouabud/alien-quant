@echo off
cd /d "%~dp0"
node run-lab.mjs --run --smoke
pause
