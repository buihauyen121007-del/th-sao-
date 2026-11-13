@echo off
cd /d "%~dp0"
echo Starting Dai Thanh Partner AI Agent Web Server on http://localhost:8055 ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\WebServer.ps1" -Port 8055 -OpenBrowser
pause
