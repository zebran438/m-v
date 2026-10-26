@echo off
cd /d "%~dp0"
docker compose down
echo Zatrzymano. Dane zostaly zachowane.
pause
