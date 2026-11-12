@echo off
title ReLoop FastAPI Backend Server
cls
echo ================================================================
echo           ReLoop FastAPI Backend API Server
echo ================================================================
echo.
echo Starting FastAPI on http://localhost:8000 ...
cd /d "C:\Users\Mithil Save\Documents\GitHub\LYB\backend"
".\.venv\Scripts\uvicorn.exe" app.main:app --host 0.0.0.0 --port 8000 --reload
pause
