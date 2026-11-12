@echo off
title ReLoop - Connect Android Phone via Wireless Debugging
cls
echo ================================================================
echo           ReLoop Wireless Debugging Setup
echo ================================================================
echo.
echo Detected Phone IP on Wi-Fi: 192.168.29.151
echo.
echo On your phone:
echo   1. Open Settings -^> Developer options -^> Wireless debugging
echo   2. Make sure the switch is ON and tap into the menu.
echo.
set ADB="C:\Users\Mithil Save\AppData\Local\Android\sdk\platform-tools\adb.exe"

set /p PAIR_CHOICE="Do you need to pair with a code? (y/n, default y): "
if "%PAIR_CHOICE%"=="" set PAIR_CHOICE=y
if /i "%PAIR_CHOICE%"=="y" (
    echo.
    echo In Wireless debugging, tap "Pair device with pairing code".
    echo A popup will show an IP & Port and a 6-digit code.
    echo.
    set /p PAIR_PORT="Enter just the 5-digit Pairing Port (e.g. 41235): "
    set /p PAIR_CODE="Enter the 6-digit Pairing Code: "
    %ADB% pair 192.168.29.151:%PAIR_PORT% %PAIR_CODE%
    echo.
)

echo.
echo Close the pairing popup. Look at the main "Wireless debugging" screen:
echo Under "IP address & Port", check the port number.
echo.
set /p CONN_PORT="Enter the Connection Port (e.g. 43311): "
%ADB% connect 192.168.29.151:%CONN_PORT%

echo.
echo Checking connection status...
%ADB% devices

echo.
echo Setting up reverse port forwarding for the backend API...
%ADB% reverse tcp:8000 tcp:8000

echo.
echo Launching ReLoop app on your phone...
%ADB% shell am start -n com.reloop.mobile/.MainActivity

echo.
echo Setup complete!
pause
