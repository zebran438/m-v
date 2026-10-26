@echo off
cd /d "%~dp0"
echo Uruchamianie M&V Engineering (pierwszy raz trwa kilka minut)...
docker compose up -d --build
if errorlevel 1 (
  echo.
  echo BLAD. Czy Docker Desktop jest uruchomiony? Poczekaj na status "Engine running" i sprobuj ponownie.
  pause
  exit /b 1
)
echo Czekam, az aplikacja wystartuje...
timeout /t 20 /nobreak >nul
start http://localhost:8080
