@echo off
title ReLoop React Web Application
cls
echo ================================================================
echo           ReLoop Circular Plastics Web Platform
echo ================================================================
echo.

echo [1/2] Checking if backend is running on http://localhost:8000 ...
curl -s http://127.0.0.1:8000/health >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Starting FastAPI backend in a separate window...
    start "ReLoop Backend" "%~dp0run_backend.bat"
    timeout /t 3 >nul
) else (
    echo [OK] Backend is already running!
)

echo.
echo [2/2] Starting Vite Frontend on http://localhost:5173 ...
cd /d "%~dp0frontend"
npm run dev -- --host 0.0.0.0 --port 5173 --open
pause
