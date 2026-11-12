@echo off
title ReLoop Mobile - Physical Android Phone
cls
echo ================================================================
echo           ReLoop Circular Plastics Mobile Platform
echo              Running on Physical Android Phone
echo ================================================================
echo.

set ADB="C:\Users\Mithil Save\AppData\Local\Android\sdk\platform-tools\adb.exe"
set FLUTTER="C:\App Devlopment\flutter\bin\flutter.bat"

echo [1/3] Checking connected Android devices...
%ADB% devices
echo.

:: Try connecting via Wi-Fi if no devices are attached
%ADB% get-state >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Attempting wireless auto-connect to phone (192.168.29.151:5555)...
    %ADB% connect 192.168.29.151:5555
)

echo [2/3] Setting up API reverse port forwarding (phone localhost:8000 -^> PC:8000)...
%ADB% reverse tcp:8000 tcp:8000
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Could not reverse port automatically. Ensure your device is connected via USB or Wi-Fi.
) else (
    echo [OK] Port 8000 reversed successfully!
)
echo.

echo [3/3] Launching ReLoop Flutter App on your physical phone...
cd /d "%~dp0mobile"
%FLUTTER% run
pause
