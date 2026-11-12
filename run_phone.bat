@echo off
title ReLoop Mobile App - Phone Emulator
cls
echo ================================================================
echo           ReLoop Circular Plastics Mobile Platform
echo ================================================================
echo.
echo [1/3] Starting Android Phone Emulator (Pixel 7)...
start "" "C:\Users\Mithil Save\AppData\Local\Android\sdk\emulator\emulator.exe" -avd Pixel_7_API_35
echo.
echo [2/3] Connecting to Phone Emulator...
"C:\Users\Mithil Save\AppData\Local\Android\sdk\platform-tools\adb.exe" wait-for-device
echo Phone connected!
echo.
echo [3/3] Launching ReLoop Flutter Application...
cd /d "C:\Users\Mithil Save\Documents\GitHub\LYB\mobile"
"C:\App Devlopment\flutter\bin\flutter.bat" run -d emulator-5554
pause
