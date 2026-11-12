@echo off
title ReLoop FastAPI Backend Server
cls
echo ================================================================
echo           ReLoop FastAPI Backend API Server
echo ================================================================
echo.

echo Checking if port 8000 is occupied...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000 ^| findstr LISTENING') do (
    echo [INFO] Found existing process (PID %%a) on port 8000. Terminating it...
    taskkill /F /PID %%a >nul 2>&1
)

echo Starting FastAPI on http://localhost:8000 ...
cd /d "%~dp0backend"
".\.venv\Scripts\uvicorn.exe" app.main:app --host 0.0.0.0 --port 8000 --reload
pause
